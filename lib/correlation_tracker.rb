# frozen_string_literal: true

# lib/correlation_tracker.rb
require 'active_support'
require 'active_support/core_ext'
require 'correlation_tracker/version'
require 'correlation_tracker/configuration'
require 'correlation_tracker/context'
require 'correlation_tracker/utilities/uuid_validator'
require 'correlation_tracker/utilities/logger'

# Load extractors
require 'correlation_tracker/extractors/base'
require 'correlation_tracker/extractors/http_extractor'
require 'correlation_tracker/extractors/webhook_extractor'
require 'correlation_tracker/extractors/email_link_extractor'

# Load middleware
require 'correlation_tracker/middleware/correlation_middleware'

# Load integrations
require 'correlation_tracker/integrations'

require 'correlation_tracker/railtie' if defined?(Rails::Railtie)

# CorrelationTracker provides distributed request tracing across microservices
# by automatically propagating correlation IDs through HTTP requests, background
# jobs, and message queues.
#
# @example Basic usage
#   # Correlation IDs are automatically set by the middleware
#   CorrelationTracker.current_id # => "550e8400-e29b-41d4-a716-446655440000"
#
# @example Manual correlation tracking
#   CorrelationTracker.set(correlation_id: 'my-custom-id', origin_type: 'cron')
#   # Make HTTP calls, enqueue jobs, etc. - correlation propagates automatically
#
# @example Temporary correlation context
#   CorrelationTracker.with_correlation(correlation_id: 'temp-id') do
#     # This block executes with the temporary correlation ID
#     # Original context is restored after the block
#   end
#
# @example Configuration
#   CorrelationTracker.configure do |config|
#     config.service_name = 'my-api'
#     config.uuid_version = 7  # Use UUID v7 (time-ordered)
#     config.validate_uuid_format = true
#   end
module CorrelationTracker
  class Error < StandardError; end
  class ConfigurationError < Error; end

  class << self
    attr_writer :configuration

    # Returns the current configuration instance
    #
    # @return [Configuration] the configuration object
    def configuration
      @configuration ||= Configuration.new
    end

    # Configures CorrelationTracker
    #
    # @example
    #   CorrelationTracker.configure do |config|
    #     config.service_name = 'my-api'
    #     config.uuid_version = 7
    #     config.header_name = 'X-Request-ID'
    #     config.validate_uuid_format = false
    #   end
    #
    # @yield [Configuration] the configuration object to modify
    # @return [void]
    def configure
      yield(configuration)
    end

    # Returns the current correlation ID for this thread
    #
    # This ID is automatically set by the Rack middleware for incoming HTTP requests,
    # or can be set manually using {#set} or {#with_correlation}.
    #
    # @return [String, nil] the current correlation ID, or nil if not set
    #
    # @example
    #   CorrelationTracker.current_id
    #   # => "550e8400-e29b-41d4-a716-446655440000"
    def current_id
      Context.correlation_id
    end

    # Returns the parent correlation ID for this thread
    #
    # The parent ID represents the correlation ID of the upstream service
    # that initiated this request. This enables building a full request trace.
    #
    # @return [String, nil] the parent correlation ID, or nil if not set
    #
    # @example
    #   CorrelationTracker.parent_id
    #   # => "550e8400-e29b-41d4-a716-446655440001"
    def parent_id
      Context.parent_correlation_id
    end

    # Returns the origin type of the current request
    #
    # Origin type indicates how the request was initiated (e.g., 'http', 'api',
    # 'webhook', 'background_job', 'cron', etc.)
    #
    # @return [String, nil] the origin type, or nil if not set
    #
    # @example
    #   CorrelationTracker.origin_type
    #   # => "api"
    def origin_type
      Context.origin_type
    end

    # Sets the correlation context for the current thread
    #
    # If no correlation_id is provided, a new one will be generated automatically.
    # Additional metadata can be passed as keyword arguments and will be stored
    # in the context if the Context class has corresponding setter methods.
    #
    # @param correlation_id [String, nil] the correlation ID to set (auto-generated if nil)
    # @param parent_id [String, nil] the parent correlation ID
    # @param origin_type [String, nil] the origin type (defaults to config.default_origin_type)
    # @param metadata [Hash] additional metadata to store in the context
    #
    # @return [String] the correlation ID that was set
    #
    # @example Set with specific ID
    #   CorrelationTracker.set(correlation_id: 'my-id', origin_type: 'cron')
    #   # => "my-id"
    #
    # @example Auto-generate ID
    #   CorrelationTracker.set(origin_type: 'background_job')
    #   # => "550e8400-e29b-41d4-a716-446655440000"
    #
    # @example With additional metadata
    #   CorrelationTracker.set(user_id: 123, customer_id: 456)
    def set(correlation_id: nil, parent_id: nil, origin_type: nil, **metadata)
      Context.correlation_id = correlation_id || generate_id
      Context.parent_correlation_id = parent_id
      Context.origin_type = origin_type || configuration.default_origin_type

      # Store additional metadata
      metadata.each do |key, value|
        Context.public_send("#{key}=", value) if Context.respond_to?("#{key}=")
      end

      Context.correlation_id
    end

    # Generates a new correlation ID using the configured generator
    #
    # By default, this generates a UUID v7 (time-ordered) if Ruby 3.3+ is available,
    # otherwise falls back to UUID v4. The generator can be customized via configuration.
    #
    # @return [String] a new correlation ID
    #
    # @example
    #   CorrelationTracker.generate_id
    #   # => "018d3e5c-8f2a-7b3c-9d4e-5f6a7b8c9d0e"
    def generate_id
      configuration.id_generator.call
    end

    # Resets the correlation context for the current thread
    #
    # This clears all correlation data including the correlation ID, parent ID,
    # origin type, and any additional metadata. Useful in tests and after
    # background job execution.
    #
    # @return [void]
    #
    # @example
    #   CorrelationTracker.current_id  # => "550e8400-..."
    #   CorrelationTracker.reset!
    #   CorrelationTracker.current_id  # => nil
    def reset!
      Context.reset
    end

    # Returns all correlation context as a hash
    #
    # The returned hash includes correlation_id, parent_correlation_id, origin_type,
    # and any additional metadata that has been set. Nil values are excluded.
    #
    # @return [Hash] hash of all correlation context with nil values removed
    #
    # @example
    #   CorrelationTracker.to_h
    #   # => {
    #   #   correlation_id: "550e8400-e29b-41d4-a716-446655440000",
    #   #   origin_type: "api",
    #   #   user_id: 123
    #   # }
    def to_h
      Context.attributes.compact
    end

    # Executes a block with a temporary correlation context
    #
    # Sets the correlation context for the duration of the block, then restores
    # the previous context. Useful for creating isolated correlation scopes
    # without affecting the surrounding context.
    #
    # @param correlation_id [String, nil] temporary correlation ID (auto-generated if nil)
    # @param options [Hash] additional options to pass to {#set}
    #
    # @yield the block to execute with the temporary context
    # @return [Object] the return value of the block
    #
    # @example
    #   CorrelationTracker.set(correlation_id: 'original-id')
    #
    #   CorrelationTracker.with_correlation(correlation_id: 'temp-id') do
    #     CorrelationTracker.current_id  # => "temp-id"
    #     # Make HTTP calls, etc.
    #   end
    #
    #   CorrelationTracker.current_id  # => "original-id"
    #
    # @example With auto-generated ID
    #   CorrelationTracker.with_correlation(origin_type: 'batch') do
    #     # Executes with new UUID and origin_type 'batch'
    #   end
    def with_correlation(correlation_id: nil, **options)
      previous_state = Context.attributes.dup

      set(correlation_id: correlation_id, **options)
      yield
    ensure
      restore_context_state(previous_state)
    end

    alias track_correlation with_correlation

    # Adds custom metadata to the current correlation context
    #
    # Metadata is stored in a separate hash and merged into the context when
    # logging or serializing. This is useful for adding request-specific
    # information that should be included in logs.
    #
    # @param key [Symbol, String] the metadata key
    # @param value [Object] the metadata value
    #
    # @return [void]
    #
    # @example
    #   CorrelationTracker.add_metadata(:request_duration_ms, 145)
    #   CorrelationTracker.add_metadata(:cache_hit, true)
    #
    #   CorrelationTracker.to_h
    #   # => {
    #   #   correlation_id: "...",
    #   #   request_duration_ms: 145,
    #   #   cache_hit: true
    #   # }
    def add_metadata(key, value)
      Context.add_metadata(key, value)
    end

    # Returns a logger instance that automatically includes correlation context
    #
    # The logger wraps the Rails logger (or a standard Logger) and automatically
    # includes correlation ID and other context in all log messages.
    #
    # @return [Utilities::Logger] logger with correlation context
    #
    # @example
    #   CorrelationTracker.logger.info("User logged in", user_id: 123)
    #   # Logs: {"message":"User logged in","correlation_id":"...","user_id":123}
    def logger
      @logger ||= Utilities::Logger.new
    end

    private

    # Restores the correlation context to a previously saved state
    #
    # This method is used internally by {#with_correlation} to ensure that
    # all context attributes are properly restored after the block executes.
    #
    # @param saved_state [Hash] the previously saved context state
    # @return [void]
    #
    # @api private
    def restore_context_state(saved_state)
      Context.reset

      # Define known predefined attributes
      known_attributes = %i[
        correlation_id parent_correlation_id origin_type
        user_id customer_id job_name webhook_source
        external_request_id email_type device_id task_type
        kafka_topic kafka_partition kafka_offset
      ]

      # Separate metadata from predefined attributes
      metadata_hash = {}

      saved_state.each do |key, value|
        next if value.nil?

        if known_attributes.include?(key)
          # Restore predefined attribute
          setter = "#{key}="
          Context.public_send(setter, value) if Context.respond_to?(setter)
        else
          # Collect metadata
          metadata_hash[key] = value
        end
      end

      # Restore metadata as a hash
      Context.metadata = metadata_hash unless metadata_hash.empty?
    end
  end
end

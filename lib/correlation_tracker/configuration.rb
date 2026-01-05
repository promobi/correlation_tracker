# lib/correlation_tracker/configuration.rb
module CorrelationTracker
  # Configuration class for CorrelationTracker
  #
  # This class manages all configuration options for the gem. Configuration
  # can be set via the {CorrelationTracker.configure} method.
  #
  # @example
  #   CorrelationTracker.configure do |config|
  #     config.service_name = 'my-api'
  #     config.uuid_version = 7
  #     config.header_name = 'X-Request-ID'
  #     config.validate_uuid_format = false
  #     config.disable_integration(:sidekiq)
  #   end
  class Configuration
    # @!attribute [rw] enabled
    #   @return [Boolean] whether correlation tracking is enabled (default: true)
    attr_accessor :enabled

    # @!attribute [rw] header_name
    #   @return [String] primary HTTP header name for correlation ID (default: 'X-Correlation-ID')
    attr_accessor :header_name

    # @!attribute [rw] parent_header_name
    #   @return [String] HTTP header name for parent correlation ID (default: 'X-Parent-Correlation-ID')
    attr_accessor :parent_header_name

    # @!attribute [rw] fallback_headers
    #   @return [Array<String>] fallback HTTP headers to check if primary header is missing (default: ['X-Request-ID', 'X-Trace-ID'])
    attr_accessor :fallback_headers

    # @!attribute [rw] uuid_version
    #   @return [Integer] UUID version to generate (4 or 7). Version 7 is time-ordered (default: 4)
    attr_accessor :uuid_version

    # @!attribute [rw] id_generator
    #   @return [Proc] custom ID generator callable. Should return a String
    #   @example
    #     config.id_generator = -> { SecureRandom.hex(16) }
    attr_accessor :id_generator

    # @!attribute [rw] default_origin_type
    #   @return [String] default origin type when not specified (default: 'http')
    attr_accessor :default_origin_type

    # @!attribute [rw] service_name
    #   @return [String] name of the current service (auto-detected from Rails app name)
    attr_accessor :service_name

    # @!attribute [rw] log_level
    #   @return [Symbol] log level for internal logging (default: :info)
    attr_accessor :log_level

    # @!attribute [rw] propagate_to_http_clients
    #   @return [Boolean] whether to automatically add correlation headers to HTTP client requests (default: true)
    attr_accessor :propagate_to_http_clients

    # @!attribute [rw] validate_uuid_format
    #   @return [Boolean] whether to validate incoming correlation IDs are valid UUIDs (default: true)
    attr_accessor :validate_uuid_format

    # @!attribute [rw] integrations
    #   @return [Hash<Symbol, Boolean>] enabled/disabled status of each integration
    attr_accessor :integrations

    # @!attribute [rw] kafka_header_key
    #   @return [String] Kafka message header key for correlation ID (default: 'correlation_id')
    attr_accessor :kafka_header_key

    # @!attribute [rw] kafka_parent_header_key
    #   @return [String] Kafka message header key for parent correlation ID (default: 'parent_correlation_id')
    attr_accessor :kafka_parent_header_key



    def initialize
      @enabled = true
      @header_name = 'X-Correlation-ID'
      @parent_header_name = 'X-Parent-Correlation-ID'
      @fallback_headers = %w[X-Request-ID X-Trace-ID]
      @id_generator = -> { SecureRandom.uuid_v7 }

      # UUID version preference
      @uuid_version = 4  # Default to v4 for backward compatibility

      # Update ID generator based on a version
      @id_generator = -> do
        case @uuid_version
        when 7
          if SecureRandom.respond_to?(:uuid_v7)
            SecureRandom.uuid_v7
          else
            CorrelationTracker::Utilities::UuidValidator.generate(7)
          end
        else
          SecureRandom.uuid
        end
      end

      @default_origin_type = 'http'
      @service_name = detect_service_name
      @log_level = :info
      @propagate_to_http_clients = true
      @validate_uuid_format = true
      @kafka_header_key = 'correlation_id'
      @kafka_parent_header_key = 'parent_correlation_id'
      @integrations = {
        action_controller: true,
        active_job: true,
        lograge: true,
        sidekiq: true,
        kafka: true,
        http_clients: true,
        opentelemetry: false
      }
    end

    # Enables a specific integration
    #
    # @param name [String, Symbol] the integration name (:action_controller, :active_job, :sidekiq, :kafka, :http_clients, :lograge, :opentelemetry)
    # @return [void]
    #
    # @example
    #   config.enable_integration(:sidekiq)
    #   config.enable_integration('kafka')
    def enable_integration(name)
      integrations[name.to_sym] = true
    end

    # Disables a specific integration
    #
    # @param name [String, Symbol] the integration name
    # @return [void]
    #
    # @example
    #   config.disable_integration(:active_job)
    def disable_integration(name)
      integrations[name.to_sym] = false
    end

    # Checks if a specific integration is enabled
    #
    # @param name [String, Symbol] the integration name
    # @return [Boolean] true if the integration is enabled
    #
    # @example
    #   config.integration_enabled?(:sidekiq)  # => true
    def integration_enabled?(name)
      integrations[name.to_sym] == true
    end

    # Sets the UUID version and updates the ID generator
    #
    # When you set the UUID version, the ID generator is automatically updated
    # to use the appropriate UUID generation method. Version 7 UUIDs are time-ordered
    # and sortable by creation time, while version 4 UUIDs are randomly generated.
    #
    # @param version [Integer] UUID version (4 or 7)
    # @raise [ArgumentError] if version is not 4 or 7
    # @return [void]
    #
    # @example
    #   config.uuid_version = 7  # Use time-ordered UUIDs
    #   config.uuid_version = 4  # Use random UUIDs
    def uuid_version=(version)
      raise ArgumentError, "UUID version must be 4 or 7" unless [4, 7].include?(version)

      @uuid_version = version

      # Update generator
      @id_generator = -> do
        case version
        when 7
          if SecureRandom.respond_to?(:uuid_v7)
            SecureRandom.uuid_v7
          else
            CorrelationTracker::Utilities::UuidValidator.generate(7)
          end
        else
          SecureRandom.uuid
        end
      end
    end

    private

    def detect_service_name
      if defined?(Rails)
        Rails.application.class.module_parent_name.underscore
      else
        'unknown'
      end
    rescue
      'unknown'
    end
  end
end
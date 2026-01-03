# lib/correlation_tracker.rb
require 'active_support/core_ext'
require 'correlation_tracker/version'
require 'correlation_tracker/configuration'
require 'correlation_tracker/context'
require 'correlation_tracker/utilities/uuid_validator'
require 'correlation_tracker/utilities/logger'
require 'correlation_tracker/railtie' if defined?(Rails::Railtie)

module CorrelationTracker
  class Error < StandardError; end
  class ConfigurationError < Error; end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    # Primary API - Get current correlation ID
    def current_id
      Context.correlation_id
    end

    # Get parent correlation ID
    def parent_id
      Context.parent_correlation_id
    end

    # Get origin type
    def origin_type
      Context.origin_type
    end

    # Set correlation context
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

    # Generate new correlation ID
    def generate_id
      configuration.id_generator.call
    end

    # Reset context (useful in tests and background jobs)
    def reset!
      Context.reset
    end

    # Get all context as hash
    def to_h
      Context.attributes.compact
    end

    # Execute block with correlation context
    def with_correlation(correlation_id: nil, **options)
      previous_id = current_id
      previous_parent = parent_id
      previous_origin = origin_type
      previous_metadata = Context.attributes.dup

      set(correlation_id: correlation_id, **options)
      yield
    ensure
      Context.correlation_id = previous_id
      Context.parent_correlation_id = previous_parent
      Context.origin_type = previous_origin
    end

    # Add metadata to current context
    def add_metadata(key, value)
      Context.add_metadata(key, value)
    end

    # Logger with correlation context
    def logger
      @logger ||= Utilities::Logger.new
    end
  end
end
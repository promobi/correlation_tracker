# lib/correlation_tracker/utilities/logger.rb
module CorrelationTracker
  module Utilities
    # Logger that automatically includes correlation context in all log messages
    #
    # This logger wraps an existing logger (Rails.logger by default) and automatically
    # merges the current correlation context into every log message as JSON.
    #
    # @example Basic usage
    #   logger = CorrelationTracker::Utilities::Logger.new
    #   logger.info("User logged in", user_id: 123)
    #   # Logs: {"message":"User logged in","correlation_id":"...","user_id":123}
    #
    # @example With hash message
    #   logger.error(message: "Payment failed", amount: 99.99, currency: "USD")
    #   # Logs: {"message":"Payment failed","correlation_id":"...","amount":99.99,"currency":"USD"}
    #
    # @example Using CorrelationTracker.logger
    #   CorrelationTracker.logger.info("Order created")
    class Logger
      # Creates a new logger instance
      #
      # @param logger [Logger, nil] the underlying logger to use. Defaults to Rails.logger if available, otherwise STDOUT
      #
      # @example
      #   logger = CorrelationTracker::Utilities::Logger.new
      #
      # @example With custom logger
      #   custom_logger = Logger.new('/var/log/app.log')
      #   logger = CorrelationTracker::Utilities::Logger.new(custom_logger)
      def initialize(logger = nil)
        @logger = logger || (defined?(Rails) ? Rails.logger : ::Logger.new(STDOUT))
      end

      # @!method debug(message = nil, **metadata)
      #   Logs a debug message with correlation context
      #   @param message [String, Hash, nil] the log message or hash
      #   @param metadata [Hash] additional metadata to include
      #   @return [void]
      #   @example
      #     logger.debug("Processing started", step: 1)

      # @!method info(message = nil, **metadata)
      #   Logs an info message with correlation context
      #   @param message [String, Hash, nil] the log message or hash
      #   @param metadata [Hash] additional metadata to include
      #   @return [void]
      #   @example
      #     logger.info("User logged in", user_id: 123)

      # @!method warn(message = nil, **metadata)
      #   Logs a warning message with correlation context
      #   @param message [String, Hash, nil] the log message or hash
      #   @param metadata [Hash] additional metadata to include
      #   @return [void]
      #   @example
      #     logger.warn("Deprecated API called", endpoint: "/api/v1/old")

      # @!method error(message = nil, **metadata)
      #   Logs an error message with correlation context
      #   @param message [String, Hash, nil] the log message or hash
      #   @param metadata [Hash] additional metadata to include
      #   @return [void]
      #   @example
      #     logger.error("Payment failed", error: e.message)

      # @!method fatal(message = nil, **metadata)
      #   Logs a fatal message with correlation context
      #   @param message [String, Hash, nil] the log message or hash
      #   @param metadata [Hash] additional metadata to include
      #   @return [void]
      #   @example
      #     logger.fatal("System shutdown", reason: "critical error")

      [:debug, :info, :warn, :error, :fatal].each do |level|
        define_method(level) do |message = nil, **metadata|
          return unless @logger.respond_to?(level)

          log_data = CorrelationTracker.to_h.merge(metadata).compact

          if message.is_a?(Hash)
            log_data.merge!(message)
            @logger.public_send(level, log_data.to_json)
          else
            log_data[:message] = message if message
            @logger.public_send(level, log_data.to_json)
          end
        end
      end
    end
  end
end
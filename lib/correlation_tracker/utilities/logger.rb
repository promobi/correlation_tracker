# lib/correlation_tracker/utilities/logger.rb
module CorrelationTracker
  module Utilities
    class Logger
      def initialize(logger = nil)
        @logger = logger || (defined?(Rails) ? Rails.logger : ::Logger.new(STDOUT))
      end

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
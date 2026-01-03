# lib/correlation_tracker/integrations/lograge.rb
module CorrelationTracker
  module Integrations
    module Lograge
      def self.setup
        return unless defined?(::Lograge)

        # Hook into Lograge configuration
        ::Lograge.custom_options = lambda do |event|
          base_options = {
            service_name: CorrelationTracker.configuration.service_name,
            timestamp: Time.now.utc.iso8601(3)
          }

          # Add correlation context
          correlation_context = CorrelationTracker.to_h

          # Add performance metrics
          performance_metrics = {
            duration_ms: event.duration&.round(2),
            view_runtime_ms: event.payload[:view_runtime]&.round(2),
            db_runtime_ms: event.payload[:db_runtime]&.round(2)
          }

          base_options.merge(correlation_context).merge(performance_metrics).compact
        end
      end
    end
  end
end

# Auto-setup if Lograge is loaded
CorrelationTracker::Integrations::Lograge.setup if defined?(Lograge)
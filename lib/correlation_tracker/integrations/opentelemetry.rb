# lib/correlation_tracker/integrations/opentelemetry.rb
module CorrelationTracker
  module Integrations
    module OpenTelemetry
      def self.setup
        return unless defined?(::OpenTelemetry)

        # Add correlation attributes to spans
        ::OpenTelemetry::Instrumentation::Rack::Middlewares::TracerMiddleware.class_eval do
          alias_method :original_call, :call

          def call(env)
            span = ::OpenTelemetry::Trace.current_span

            if span && CorrelationTracker.current_id
              span.set_attribute('correlation.id', CorrelationTracker.current_id)
              span.set_attribute('correlation.parent_id', CorrelationTracker.parent_id) if CorrelationTracker.parent_id
              span.set_attribute('correlation.origin_type', CorrelationTracker.origin_type)
            end

            original_call(env)
          end
        end
      end
    end
  end
end

# Auto-setup if OpenTelemetry is loaded
CorrelationTracker::Integrations::OpenTelemetry.setup if defined?(OpenTelemetry)
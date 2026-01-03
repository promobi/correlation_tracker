# lib/correlation_tracker/integrations/http_clients/faraday.rb
module CorrelationTracker
  module Integrations
    module HttpClients
      class FaradayMiddleware < Faraday::Middleware
        def call(env)
          add_correlation_headers(env) if CorrelationTracker.configuration.propagate_to_http_clients

          @app.call(env)
        end

        private

        def add_correlation_headers(env)
          config = CorrelationTracker.configuration
          correlation_id = CorrelationTracker.current_id

          return unless correlation_id

          env.request_headers[config.header_name] = correlation_id
          env.request_headers[config.parent_header_name] = correlation_id
        end
      end
    end
  end
end

# Register with Faraday
if defined?(Faraday)
  Faraday::Request.register_middleware(
    correlation_tracker: CorrelationTracker::Integrations::HttpClients::FaradayMiddleware
  )
end
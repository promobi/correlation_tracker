# lib/correlation_tracker/middleware/correlation_middleware.rb
require 'correlation_tracker/extractors/http_extractor'
require 'correlation_tracker/extractors/webhook_extractor'
require 'correlation_tracker/extractors/email_link_extractor'

module CorrelationTracker
  module Middleware
    class CorrelationMiddleware
      def initialize(app)
        @app = app
      end

      def call(env)
        return @app.call(env) unless CorrelationTracker.configuration.enabled

        setup_correlation_context(env)

        status, headers, response = @app.call(env)

        # Echo correlation ID in response
        if CorrelationTracker.current_id
          headers[CorrelationTracker.configuration.header_name] = CorrelationTracker.current_id
        end

        [status, headers, response]
      ensure
        CorrelationTracker.reset!
      end

      private

      def setup_correlation_context(env)
        request = Rack::Request.new(env)
        extractor = determine_extractor(request)

        correlation_data = extractor.extract(request)
        CorrelationTracker.set(**correlation_data)

        # Store in env for downstream middleware
        env['correlation_tracker.id'] = CorrelationTracker.current_id
        env['correlation_tracker.origin_type'] = CorrelationTracker.origin_type

        # Emit notification
        ActiveSupport::Notifications.instrument(
          'correlation_tracker.correlation_set',
          correlation_data
        )
      end

      def determine_extractor(request)
        path = request.path

        if path.start_with?('/webhooks')
          Extractors::WebhookExtractor.new
        elsif path.match?(/\/(verify|reset|confirm|activate)/)
          Extractors::EmailLinkExtractor.new
        else
          Extractors::HttpExtractor.new
        end
      end
    end
  end
end
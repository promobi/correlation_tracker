# lib/correlation_tracker/extractors/webhook_extractor.rb
module CorrelationTracker
  module Extractors
    class WebhookExtractor < Base
      WEBHOOK_SIGNATURES = {
        'HTTP_STRIPE_SIGNATURE' => 'stripe',
        'HTTP_X_GITHUB_EVENT' => 'github',
        'HTTP_X_SHOPIFY_HMAC_SHA256' => 'shopify',
        'HTTP_X_SLACK_SIGNATURE' => 'slack',
        'HTTP_X_TWILIO_SIGNATURE' => 'twilio'
      }.freeze

      def extract(request)
        {
          correlation_id: extract_correlation_id(request),
          parent_correlation_id: extract_header(request, CorrelationTracker.configuration.parent_header_name),
          origin_type: 'webhook',
          webhook_source: detect_webhook_source(request),
          external_request_id: extract_external_request_id(request)
        }
      end

      private

      def detect_webhook_source(request)
        # Try to extract from path first: /webhooks/stripe -> 'stripe'
        if request.path.match(%r{/webhooks/(\w+)})
          return $1
        end

        # Try to detect from headers
        WEBHOOK_SIGNATURES.each do |header, source|
          return source if request.env[header]
        end

        'unknown'
      end

      def extract_external_request_id(request)
        # Common webhook delivery ID headers
        request.env['HTTP_X_REQUEST_ID'] ||
          request.env['HTTP_X_DELIVERY_ID'] ||
          request.env['HTTP_X_GITHUB_DELIVERY'] ||
          request.env['HTTP_X_AMZN_TRACE_ID'] ||
          request.env['HTTP_STRIPE_SIGNATURE']&.split(',')&.first
      end
    end
  end
end
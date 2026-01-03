# lib/correlation_tracker/extractors/email_link_extractor.rb
module CorrelationTracker
  module Extractors
    class EmailLinkExtractor < Base
      def extract(request)
        {
          correlation_id: extract_correlation_id(request),
          parent_correlation_id: extract_from_token(request),
          origin_type: 'email_link',
          email_type: detect_email_type(request)
        }
      end

      private

      def extract_from_token(request)
        # This is intentionally left simple - actual implementation
        # depends on your token structure (JWT, Rails signed messages, etc.)
        token = request.params['token']
        return nil unless token

        # Override this method in your app to decode your specific token format
        nil
      end

      def detect_email_type(request)
        path = request.path

        return 'email_verification' if path.include?('verify')
        return 'password_reset' if path.include?('reset')
        return 'invitation' if path.include?('invite') || path.include?('accept')
        return 'confirmation' if path.include?('confirm')
        return 'activation' if path.include?('activate')

        'unknown'
      end
    end
  end
end
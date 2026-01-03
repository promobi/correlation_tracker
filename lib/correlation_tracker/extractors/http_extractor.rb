# lib/correlation_tracker/extractors/http_extractor.rb
module CorrelationTracker
  module Extractors
    class HttpExtractor < Base
      def extract(request)
        {
          correlation_id: extract_correlation_id(request),
          parent_correlation_id: extract_parent_id(request),
          origin_type: determine_origin_type(request)
        }
      end

      private

      def extract_parent_id(request)
        extract_header(request, CorrelationTracker.configuration.parent_header_name)
      end

      def determine_origin_type(request)
        path = request.path

        return 'api' if path.start_with?('/api')
        return 'webhook' if path.start_with?('/webhooks')

        'http'
      end
    end
  end
end
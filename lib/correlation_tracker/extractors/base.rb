# lib/correlation_tracker/extractors/base.rb
module CorrelationTracker
  module Extractors
    class Base
      def extract(request)
        raise NotImplementedError, "#{self.class} must implement #extract"
      end

      protected

      def extract_header(request, header_name)
        rack_header = "HTTP_#{header_name.upcase.tr('-', '_')}"
        request.env[rack_header].presence
      end

      def extract_correlation_id(request)
        config = CorrelationTracker.configuration

        # Try primary header
        correlation_id = extract_header(request, config.header_name)
        return correlation_id if valid_uuid?(correlation_id)

        # Try fallback headers
        config.fallback_headers.each do |header|
          correlation_id = extract_header(request, header)
          return correlation_id if valid_uuid?(correlation_id)
        end

        nil
      end

      def valid_uuid?(value)
        return false if value.blank?
        return true unless CorrelationTracker.configuration.validate_uuid_format

        Utilities::UuidValidator.valid?(value)
      end
    end
  end
end
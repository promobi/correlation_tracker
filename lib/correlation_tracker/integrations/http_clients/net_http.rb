# lib/correlation_tracker/integrations/http_clients/net_http.rb
require 'net/http'

module CorrelationTracker
  module Integrations
    module HttpClients
      module NetHTTPExtension
        def request(req, body = nil, &block)
          add_correlation_headers(req) if CorrelationTracker.configuration.propagate_to_http_clients
          super
        end

        private

        def add_correlation_headers(request)
          config = CorrelationTracker.configuration
          correlation_id = CorrelationTracker.current_id

          return unless correlation_id

          request[config.header_name] = correlation_id
          request[config.parent_header_name] = correlation_id
        end
      end
    end
  end
end

# Patch Net::HTTP
Net::HTTP.prepend(CorrelationTracker::Integrations::HttpClients::NetHTTPExtension)
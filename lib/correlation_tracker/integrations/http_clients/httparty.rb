# lib/correlation_tracker/integrations/http_clients/httparty.rb
module CorrelationTracker
  module Integrations
    module HttpClients
      module HTTPartyIntegration
        def self.included(base)
          base.headers(correlation_headers) if CorrelationTracker.configuration.propagate_to_http_clients
        end

        def self.correlation_headers
          config = CorrelationTracker.configuration
          correlation_id = CorrelationTracker.current_id

          return {} unless correlation_id

          {
            config.header_name => correlation_id,
            config.parent_header_name => correlation_id
          }
        end
      end
    end
  end
end

# Usage in HTTParty classes:
# class MyApiClient
#   include HTTParty
#   include CorrelationTracker::Integrations::HttpClients::HTTPartyIntegration
# end
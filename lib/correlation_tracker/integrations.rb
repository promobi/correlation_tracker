# lib/correlation_tracker/integrations.rb
module CorrelationTracker
  module Integrations
    class << self
      def load_enabled_integrations
        config = CorrelationTracker.configuration

        load_integration('action_controller') if config.integration_enabled?(:action_controller)
        load_integration('active_job') if config.integration_enabled?(:active_job)
        load_integration('lograge') if config.integration_enabled?(:lograge) && defined?(Lograge)
        load_integration('sidekiq') if config.integration_enabled?(:sidekiq) && defined?(Sidekiq)
        load_integration('kafka') if config.integration_enabled?(:kafka) && defined?(Kafka)
        load_integration('http_clients/faraday') if config.integration_enabled?(:http_clients) && defined?(Faraday)
        load_integration('http_clients/httparty') if config.integration_enabled?(:http_clients) && defined?(HTTParty)
        load_integration('http_clients/net_http') if config.integration_enabled?(:http_clients)
        load_integration('opentelemetry') if config.integration_enabled?(:opentelemetry) && defined?(OpenTelemetry)
      end

      private

      def load_integration(name)
        require "correlation_tracker/integrations/#{name}"
      rescue LoadError => e
        warn_about_missing_integration(name, e)
      end

      def warn_about_missing_integration(name, error)
        if defined?(Rails) && Rails.logger
          Rails.logger.warn(
            "CorrelationTracker: Could not load #{name} integration: #{error.message}"
          )
        end
      end
    end
  end
end
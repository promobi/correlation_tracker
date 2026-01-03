# lib/correlation_tracker/configuration.rb
module CorrelationTracker
  class Configuration
    attr_accessor :enabled,
                  :header_name,
                  :parent_header_name,
                  :fallback_headers,
                  :id_generator,
                  :default_origin_type,
                  :service_name,
                  :log_level,
                  :propagate_to_http_clients,
                  :validate_uuid_format,
                  :integrations,
                  :kafka_header_key,
                  :kafka_parent_header_key

    def initialize
      @enabled = true
      @header_name = 'X-Correlation-ID'
      @parent_header_name = 'X-Parent-Correlation-ID'
      @fallback_headers = %w[X-Request-ID X-Trace-ID]
      @id_generator = -> { SecureRandom.uuid_v7 }
      @default_origin_type = 'http'
      @service_name = detect_service_name
      @log_level = :info
      @propagate_to_http_clients = true
      @validate_uuid_format = true
      @kafka_header_key = 'correlation_id'
      @kafka_parent_header_key = 'parent_correlation_id'
      @integrations = {
        action_controller: true,
        active_job: true,
        lograge: true,
        sidekiq: true,
        kafka: true,
        http_clients: true,
        opentelemetry: false
      }
    end

    # Enable/disable specific integration
    def enable_integration(name)
      integrations[name.to_sym] = true
    end

    def disable_integration(name)
      integrations[name.to_sym] = false
    end

    def integration_enabled?(name)
      integrations[name.to_sym] == true
    end

    private

    def detect_service_name
      if defined?(Rails)
        Rails.application.class.module_parent_name.underscore
      else
        'unknown'
      end
    rescue
      'unknown'
    end
  end
end
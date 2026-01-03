# lib/generators/correlation_tracker/templates/correlation_tracker.rb
CorrelationTracker.configure do |config|
  # Service identification
  config.service_name = '<%= Rails.application.class.module_parent_name.underscore %>'

  # Header configuration
  config.header_name = 'X-Correlation-ID'
  config.parent_header_name = 'X-Parent-Correlation-ID'
  config.fallback_headers = %w[X-Request-ID X-Trace-ID]

  # ID generation
  # Default: SecureRandom.uuid (UUID v4)
  # For sortable IDs, consider UUID v7:
  config.id_generator = -> { SecureRandom.uuid_v7 } # Ruby 3.3+

  # Kafka configuration (if using Kafka)
  config.kafka_header_key = 'correlation_id'
  config.kafka_parent_header_key = 'parent_correlation_id'

  # Enable/disable integrations
  config.enable_integration(:action_controller)
  config.enable_integration(:active_job)
  config.enable_integration(:lograge)
  config.enable_integration(:sidekiq)
  config.enable_integration(:kafka)
  config.enable_integration(:http_clients)

  # OpenTelemetry (optional)
  # config.enable_integration(:opentelemetry)

  # Validation
  config.validate_uuid_format = true

  # Logging
  config.log_level = :info # :debug for verbose logging
end
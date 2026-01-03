# lib/correlation_tracker/railtie.rb
require 'rails/railtie'
require 'correlation_tracker/middleware/correlation_middleware'
require 'correlation_tracker/integrations'

module CorrelationTracker
  class Railtie < Rails::Railtie
    config.correlation_tracker = CorrelationTracker.configuration

    initializer 'correlation_tracker.configure_middleware' do |app|
      if CorrelationTracker.configuration.enabled
        app.config.middleware.insert_before(
          ActionDispatch::RequestId,
          CorrelationTracker::Middleware::CorrelationMiddleware
        )
      end
    end

    # Load integrations after Rails initialization
    config.after_initialize do
      CorrelationTracker::Integrations.load_enabled_integrations
    end

    # ActiveSupport notifications for debugging
    initializer 'correlation_tracker.setup_notifications' do
      ActiveSupport::Notifications.subscribe('correlation_tracker.correlation_set') do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)

        if CorrelationTracker.configuration.log_level == :debug
          Rails.logger.debug(
            "CorrelationTracker: Set correlation_id=#{event.payload[:correlation_id]}, " \
              "origin_type=#{event.payload[:origin_type]}"
          )
        end
      end
    end

    # Rake tasks
    rake_tasks do
      load 'correlation_tracker/tasks/correlation_tracker.rake'
    end
  end
end
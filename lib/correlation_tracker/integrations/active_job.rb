# lib/correlation_tracker/integrations/active_job.rb
module CorrelationTracker
  module Integrations
    module ActiveJob
      extend ActiveSupport::Concern

      included do
        around_perform :with_correlation_tracking
        before_enqueue :attach_correlation_to_job
      end

      private

      def with_correlation_tracking
        # Extract correlation from arguments
        correlation_context = extract_correlation_context

        CorrelationTracker.set(
          correlation_id: correlation_context[:correlation_id],
          parent_correlation_id: correlation_context[:parent_correlation_id],
          origin_type: 'background_job',
          job_name: self.class.name
        )

        log_job_event(:started)

        result = nil
        begin
          result = yield
          log_job_event(:completed)
          result
        rescue => e
          log_job_event(:failed, error: e)
          raise
        end
      ensure
        CorrelationTracker.reset!
      end

      def attach_correlation_to_job
        # Automatically attach current correlation to job arguments if not present
        unless has_correlation_in_args?
          arguments << {
            correlation_id: CorrelationTracker.current_id || CorrelationTracker.generate_id,
            parent_correlation_id: CorrelationTracker.current_id
          }
        end
      end

      def has_correlation_in_args?
        arguments.any? { |arg| arg.is_a?(Hash) && arg.key?(:correlation_id) }
      end

      def extract_correlation_context
        args_hash = arguments.find { |arg| arg.is_a?(Hash) && arg.key?(:correlation_id) }

        {
          correlation_id: args_hash&.dig(:correlation_id),
          parent_correlation_id: args_hash&.dig(:parent_correlation_id)
        }
      end

      def log_job_event(event_type, **extra_data)
        log_data = {
          message: "Job #{event_type}",
          job_id: job_id,
          queue: queue_name,
          executions: executions
        }.merge(CorrelationTracker.to_h).merge(extra_data)

        case event_type
        when :failed
          log_data[:error_class] = extra_data[:error].class.name
          log_data[:error_message] = extra_data[:error].message
          log_data[:backtrace] = extra_data[:error].backtrace.first(10)
          Rails.logger.error(log_data.to_json)
        else
          Rails.logger.info(log_data.to_json)
        end
      end
    end
  end
end

# Auto-include in all jobs
ActiveSupport.on_load(:active_job) do
  include CorrelationTracker::Integrations::ActiveJob
end
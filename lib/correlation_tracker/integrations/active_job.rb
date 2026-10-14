# lib/correlation_tracker/integrations/active_job.rb
module CorrelationTracker
  module Integrations
    # ActiveJob integration for automatic correlation tracking in background jobs
    #
    # This module is automatically included in all ActiveJob::Base jobs when
    # CorrelationTracker is loaded in a Rails application.
    #
    # It provides:
    # - Automatic correlation ID attachment when enqueueing jobs
    # - Correlation context restoration when executing jobs
    # - Automatic logging of job lifecycle events (started, completed, failed)
    # - Parent-child correlation tracking across job hierarchies
    #
    # @example Correlation automatically propagates to jobs
    #   # In a controller or service
    #   CorrelationTracker.current_id  # => "550e8400-..."
    #   MyJob.perform_later(user_id: 123)
    #
    #   # Inside MyJob#perform
    #   CorrelationTracker.current_id  # => "550e8400-..." (same ID)
    #   CorrelationTracker.origin_type # => "background_job"
    #
    # @example Manual inclusion (if auto-include is disabled)
    #   class MyJob < ActiveJob::Base
    #     include CorrelationTracker::Integrations::ActiveJob
    #
    #     def perform(user_id)
    #       # Correlation context is available here
    #     end
    #   end
    module ActiveJob
      extend ActiveSupport::Concern

      # Keys the correlation travels under in the job's serialized data, next to ActiveJob's own
      # ("job_class", "arguments", ...). Never in the arguments: perform gets exactly what was
      # passed to perform_later.
      CORRELATION_KEYS = %w[correlation_id parent_correlation_id].freeze

      included do
        attr_accessor :tracked_correlation_id, :tracked_parent_correlation_id

        around_perform :with_correlation_tracking
        before_enqueue :attach_correlation_to_job
      end

      def serialize
        super.merge(
          'correlation_id' => tracked_correlation_id,
          'parent_correlation_id' => tracked_parent_correlation_id
        )
      end

      def deserialize(job_data)
        super
        self.tracked_correlation_id = job_data['correlation_id']
        self.tracked_parent_correlation_id = job_data['parent_correlation_id']
      end

      private

      def with_correlation_tracking
        # Extract correlation from the job data, or from a job queued by an older version
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
        # Keep the correlation the job already has, as on a retry
        return if tracked_correlation_id

        self.tracked_correlation_id = CorrelationTracker.current_id || CorrelationTracker.generate_id
        self.tracked_parent_correlation_id = CorrelationTracker.current_id
      end

      # The correlation for this run. A job queued by an older version of this gem carries it as
      # an extra last argument instead; that argument is taken off here, before perform, which
      # would otherwise get one argument too many.
      def extract_correlation_context
        legacy = take_legacy_correlation_argument

        {
          correlation_id: tracked_correlation_id || legacy&.dig(:correlation_id),
          parent_correlation_id: tracked_parent_correlation_id || legacy&.dig(:parent_correlation_id)
        }
      end

      # The trailing Hash older versions appended, which holds these two keys and nothing else.
      def take_legacy_correlation_argument
        last = arguments.last
        return unless last.is_a?(Hash) && last.key?(:correlation_id) &&
                      (last.keys - %i[correlation_id parent_correlation_id]).empty?

        arguments.pop
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
          Rails.logger.error(log_data)
        else
          Rails.logger.info(log_data)
        end
      end
    end
  end
end

# Auto-include in all jobs
ActiveSupport.on_load(:active_job) do
  include CorrelationTracker::Integrations::ActiveJob
end
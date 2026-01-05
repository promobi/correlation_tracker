# lib/correlation_tracker/integrations/sidekiq.rb
module CorrelationTracker
  module Integrations
    # Sidekiq integration for automatic correlation tracking
    #
    # Provides two middlewares:
    # - ClientMiddleware: Attaches correlation ID when enqueueing jobs
    # - ServerMiddleware: Restores correlation context when executing jobs
    #
    # These middlewares are automatically registered with Sidekiq when the gem
    # is loaded and Sidekiq is available.
    #
    # @example Correlation automatically propagates through Sidekiq
    #   # In a service or controller
    #   CorrelationTracker.current_id  # => "550e8400-..."
    #   MyWorker.perform_async(user_id: 123)
    #
    #   # Inside MyWorker#perform
    #   CorrelationTracker.current_id  # => "550e8400-..." (same ID)
    #   CorrelationTracker.origin_type # => "sidekiq_job"
    #
    # @example Manual registration (if auto-registration is disabled)
    #   Sidekiq.configure_client do |config|
    #     config.client_middleware do |chain|
    #       chain.add CorrelationTracker::Integrations::Sidekiq::ClientMiddleware
    #     end
    #   end
    #
    #   Sidekiq.configure_server do |config|
    #     config.server_middleware do |chain|
    #       chain.add CorrelationTracker::Integrations::Sidekiq::ServerMiddleware
    #     end
    #   end
    module Sidekiq
      # Client-side middleware for attaching correlation to Sidekiq jobs
      #
      # This middleware runs when a job is enqueued and attaches the current
      # correlation ID to the job payload.
      #
      # @api private
      class ClientMiddleware
        def call(worker_class, job, queue, redis_pool)
          # Attach correlation to job payload
          job['correlation_id'] ||= CorrelationTracker.current_id || CorrelationTracker.generate_id
          job['parent_correlation_id'] ||= CorrelationTracker&.current_id
          job['origin_type'] = 'sidekiq_job'

          yield
        end
      end

      # Server-side middleware for restoring correlation in Sidekiq workers
      #
      # This middleware runs when a job is executed and restores the correlation
      # context from the job payload. It also logs job lifecycle events.
      #
      # @api private
      class ServerMiddleware
        def call(worker, job, queue)
          # Set correlation context from job
          CorrelationTracker.set(
            correlation_id: job['correlation_id'],
            parent_correlation_id: job['parent_correlation_id'],
            origin_type: 'sidekiq_job',
            job_name: worker.class.name
          )

          log_job_start(worker, job, queue)

          begin
            yield
            log_job_completion(worker, job)
          rescue => e
            log_job_failure(worker, job, e)
            raise
          end
        ensure
          CorrelationTracker.reset!
        end

        private

        def log_job_start(worker, job, queue)
          return unless logger

          logger.info(
            message: "Sidekiq job started",
            worker: worker.class.name,
            jid: job['jid'],
            queue: queue,
            **CorrelationTracker.to_h
          )
        end

        def log_job_completion(worker, job)
          return unless logger

          logger.info(
            message: "Sidekiq job completed",
            worker: worker.class.name,
            jid: job['jid'],
            **CorrelationTracker.to_h
          )
        end

        def log_job_failure(worker, job, error)
          return unless logger

          logger.error(
            message: "Sidekiq job failed",
            worker: worker.class.name,
            jid: job['jid'],
            error_class: error.class.name,
            error_message: error.message,
            backtrace: error.backtrace.first(10),
            **CorrelationTracker.to_h
          )
        end

        def logger
          defined?(Rails) ? Rails.logger : nil
        end
      end
    end
  end
end

# Auto-configure Sidekiq
if defined?(::Sidekiq)
  ::Sidekiq.configure_client do |config|
    config.client_middleware do |chain|
      chain.add CorrelationTracker::Integrations::Sidekiq::ClientMiddleware
    end
  end

  ::Sidekiq.configure_server do |config|
    config.client_middleware do |chain|
      chain.add CorrelationTracker::Integrations::Sidekiq::ClientMiddleware
    end

    config.server_middleware do |chain|
      chain.add CorrelationTracker::Integrations::Sidekiq::ServerMiddleware
    end
  end
end
# lib/correlation_tracker/integrations/sidekiq.rb
module CorrelationTracker
  module Integrations
    module Sidekiq
      class ClientMiddleware
        def call(worker_class, job, queue, redis_pool)
          # Attach correlation to job payload
          job['correlation_id'] ||= CorrelationTracker.current_id || CorrelationTracker.generate_id
          job['parent_correlation_id'] ||= CorrelationTracker&.current_id
          job['origin_type'] = 'sidekiq_job'

          yield
        end
      end

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
          Rails.logger.info(
            message: "Sidekiq job started",
            worker: worker.class.name,
            jid: job['jid'],
            queue: queue,
            **CorrelationTracker.to_h
          )
        end

        def log_job_completion(worker, job)
          Rails.logger.info(
            message: "Sidekiq job completed",
            worker: worker.class.name,
            jid: job['jid'],
            **CorrelationTracker.to_h
          )
        end

        def log_job_failure(worker, job, error)
          Rails.logger.error(
            message: "Sidekiq job failed",
            worker: worker.class.name,
            jid: job['jid'],
            error_class: error.class.name,
            error_message: error.message,
            backtrace: error.backtrace.first(10),
            **CorrelationTracker.to_h
          )
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
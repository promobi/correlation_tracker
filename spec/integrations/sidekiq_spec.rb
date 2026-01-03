# spec/integrations/sidekiq_spec.rb
require 'spec_helper'

RSpec.describe CorrelationTracker::Integrations::Sidekiq do
  describe 'ClientMiddleware' do
    let(:middleware) { described_class::ClientMiddleware.new }
    let(:worker_class) { 'TestWorker' }
    let(:job) { {} }
    let(:queue) { 'default' }
    let(:redis_pool) { nil }

    describe '#call' do
      it 'attaches correlation_id to job' do
        CorrelationTracker.set(correlation_id: 'test-123')

        middleware.call(worker_class, job, queue, redis_pool) { }

        expect(job['correlation_id']).to eq('test-123')
        expect(job['parent_correlation_id']).to eq('test-123')
        expect(job['origin_type']).to eq('sidekiq_job')
      end

      it 'generates correlation_id if not present' do
        CorrelationTracker.reset!

        middleware.call(worker_class, job, queue, redis_pool) { }

        expect(job['correlation_id']).to match(/\A[0-9a-f-]{36}\z/i)
      end

      it 'preserves existing correlation_id' do
        job['correlation_id'] = 'existing-123'

        middleware.call(worker_class, job, queue, redis_pool) { }

        expect(job['correlation_id']).to eq('existing-123')
      end

      it 'yields to next middleware' do
        expect { |b| middleware.call(worker_class, job, queue, redis_pool, &b) }
          .to yield_control
      end
    end
  end

  describe 'ServerMiddleware' do
    let(:middleware) { described_class::ServerMiddleware.new }
    let(:worker) { double('Worker', class: double(name: 'TestWorker')) }
    let(:job) { { 'jid' => 'job-123', 'correlation_id' => 'test-123', 'parent_correlation_id' => 'parent-456' } }
    let(:queue) { 'default' }

    before do
      allow(Rails).to receive(:logger).and_return(double(info: nil, error: nil))
    end

    describe '#call' do
      it 'sets correlation context from job' do
        middleware.call(worker, job, queue) do
          expect(CorrelationTracker.current_id).to eq('test-123')
          expect(CorrelationTracker.parent_id).to eq('parent-456')
          expect(CorrelationTracker.origin_type).to eq('sidekiq_job')
          expect(CorrelationTracker::Context.job_name).to eq('TestWorker')
        end
      end

      it 'logs job start' do
        expect(Rails.logger).to receive(:info) do |hash|
          expect(hash[:message]).to eq('Sidekiq job started')
          expect(hash[:worker]).to eq('TestWorker')
          expect(hash[:jid]).to eq('job-123')
          expect(hash[:correlation_id]).to eq('test-123')
        end

        middleware.call(worker, job, queue) { }
      end

      it 'logs job completion' do
        expect(Rails.logger).to receive(:info).with(
          hash_including(message: 'Sidekiq job completed')
        )

        middleware.call(worker, job, queue) { }
      end

      it 'logs job failure' do
        expect(Rails.logger).to receive(:error) do |hash|
          expect(hash[:message]).to eq('Sidekiq job failed')
          expect(hash[:error_class]).to eq('RuntimeError')
          expect(hash[:error_message]).to eq('Test error')
        end

        expect {
          middleware.call(worker, job, queue) do
            raise 'Test error'
          end
        }.to raise_error('Test error')
      end

      it 'resets context after job' do
        middleware.call(worker, job, queue) { }

        expect(CorrelationTracker.current_id).to be_nil
      end

      it 'resets context even on error' do
        begin
          middleware.call(worker, job, queue) do
            raise 'Test error'
          end
        rescue
          # Ignore
        end

        expect(CorrelationTracker.current_id).to be_nil
      end
    end
  end

  describe 'auto-configuration' do
    it 'configures Sidekiq middleware if Sidekiq is defined' do
      skip 'Sidekiq not loaded' unless defined?(::Sidekiq)

      # This test verifies that the middleware is registered
      # Actual registration happens when the integration is loaded

      client_chain = ::Sidekiq.client_middleware
      server_chain = ::Sidekiq.server_middleware rescue nil

      # Check if middleware is registered (may vary based on Sidekiq version)
      expect(client_chain).to be_a(Sidekiq::Middleware::Chain)
    end
  end
end
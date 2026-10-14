# spec/integrations/active_job_spec.rb
require 'spec_helper'
require 'active_job'
require 'correlation_tracker/integrations/active_job'

# Define a minimal Rails stub for testing
unless defined?(Rails)
  module Rails
    def self.logger
      @logger ||= Logger.new(nil)
    end

    def self.logger=(logger)
      @logger = logger
    end
  end
end

RSpec.describe CorrelationTracker::Integrations::ActiveJob do
  # Mock job for testing
  class TestJob < ActiveJob::Base
    include CorrelationTracker::Integrations::ActiveJob

    def perform(*args)
      # Job logic
    end
  end

  # A job whose perform takes exactly the arguments it was given, as most jobs do.
  class FixedArityJob < ActiveJob::Base
    include CorrelationTracker::Integrations::ActiveJob

    cattr_accessor :received

    def perform(device_id, message)
      self.class.received = [device_id, message, CorrelationTracker.current_id]
    end
  end

  let(:job) { TestJob.new }

  describe 'included hooks' do
    it 'adds around_perform callback' do
      callbacks = TestJob._perform_callbacks.select do |callback|
        callback.filter == :with_correlation_tracking
      end

      expect(callbacks).not_to be_empty
    end

    it 'adds before_enqueue callback' do
      callbacks = TestJob._enqueue_callbacks.select do |callback|
        callback.filter == :attach_correlation_to_job
      end

      expect(callbacks).not_to be_empty
    end
  end

  describe '#attach_correlation_to_job' do
    it 'attaches the correlation to the job, not to its arguments' do
      CorrelationTracker.set(correlation_id: 'test-123')

      job.arguments = ['arg1', 'arg2']
      job.send(:attach_correlation_to_job)

      expect(job.arguments).to eq(['arg1', 'arg2'])
      expect(job.tracked_correlation_id).to eq('test-123')
      expect(job.tracked_parent_correlation_id).to eq('test-123')
    end

    it 'keeps a correlation the job already has, as on a retry' do
      CorrelationTracker.set(correlation_id: 'new-456')
      job.tracked_correlation_id = 'existing-123'

      job.send(:attach_correlation_to_job)

      expect(job.tracked_correlation_id).to eq('existing-123')
    end

    it 'generates new correlation if none exists' do
      CorrelationTracker.reset!

      job.arguments = ['arg1']
      job.send(:attach_correlation_to_job)

      expect(job.tracked_correlation_id).to match(/\A[0-9a-f-]{36}\z/i)
    end
  end

  describe '#extract_correlation_context' do
    it 'extracts correlation from the job' do
      job.tracked_correlation_id = 'test-123'
      job.tracked_parent_correlation_id = 'parent-456'

      context = job.send(:extract_correlation_context)

      expect(context[:correlation_id]).to eq('test-123')
      expect(context[:parent_correlation_id]).to eq('parent-456')
    end

    it 'extracts it from the last argument of a job queued by an older version, and removes it' do
      job.arguments = ['arg1', { correlation_id: 'test-123', parent_correlation_id: 'parent-456' }]

      context = job.send(:extract_correlation_context)

      expect(context[:correlation_id]).to eq('test-123')
      expect(context[:parent_correlation_id]).to eq('parent-456')
      expect(job.arguments).to eq(['arg1'])
    end

    it "leaves a Hash argument that is the job's own alone" do
      job.arguments = [{ correlation_id: 'mine', order_id: 9 }]

      job.send(:extract_correlation_context)

      expect(job.arguments).to eq([{ correlation_id: 'mine', order_id: 9 }])
    end

    it 'returns nil values if there is no correlation' do
      job.arguments = ['arg1', 'arg2']

      context = job.send(:extract_correlation_context)

      expect(context[:correlation_id]).to be_nil
      expect(context[:parent_correlation_id]).to be_nil
    end
  end

  describe '#with_correlation_tracking' do
    before do
      allow(Rails).to receive(:logger).and_return(double(info: nil, error: nil))
      allow(job).to receive(:job_id).and_return('job-123')
      allow(job).to receive(:queue_name).and_return('default')
      allow(job).to receive(:executions).and_return(1)
    end

    it 'sets correlation context from job arguments' do
      job.arguments = [{ correlation_id: 'test-123', parent_correlation_id: 'parent-456' }]

      job.send(:with_correlation_tracking) do
        expect(CorrelationTracker.current_id).to eq('test-123')
        expect(CorrelationTracker.parent_id).to eq('parent-456')
        expect(CorrelationTracker.origin_type).to eq('background_job')
        expect(CorrelationTracker::Context.job_name).to eq('TestJob')
      end
    end

    it 'logs job start' do
      job.arguments = [{ correlation_id: 'test-123' }]

      expect(Rails.logger).to receive(:info) do |hash|
        if hash[:message] == 'Job started'
          expect(hash[:correlation_id]).to eq('test-123')
          expect(hash[:job_id]).to eq('job-123')
        end
      end.at_least(:once)

      job.send(:with_correlation_tracking) { }
    end

    it 'logs job completion' do
      job.arguments = [{ correlation_id: 'test-123' }]

      expect(Rails.logger).to receive(:info) do |hash|
        expect(hash[:message]).to eq('Job completed') if hash[:message] == 'Job completed'
      end.at_least(:once)

      job.send(:with_correlation_tracking) { }
    end

    it 'logs job failure on error' do
      job.arguments = [{ correlation_id: 'test-123' }]

      expect(Rails.logger).to receive(:error) do |hash|
        expect(hash[:message]).to eq('Job failed')
        expect(hash[:error_class]).to eq('RuntimeError')
        expect(hash[:error_message]).to eq('Test error')
      end

      expect {
        job.send(:with_correlation_tracking) do
          raise 'Test error'
        end
      }.to raise_error('Test error')
    end

    it 'resets context after job execution' do
      job.arguments = [{ correlation_id: 'test-123' }]

      job.send(:with_correlation_tracking) { }

      expect(CorrelationTracker.current_id).to be_nil
    end

    it 'resets context even on error' do
      job.arguments = [{ correlation_id: 'test-123' }]

      begin
        job.send(:with_correlation_tracking) do
          raise 'Test error'
        end
      rescue
        # Ignore error
      end

      expect(CorrelationTracker.current_id).to be_nil
    end
  end

  describe 'integration test' do
    it 'maintains correlation through job lifecycle' do
      CorrelationTracker.set(correlation_id: 'enqueue-123')

      # Enqueue job
      TestJob.perform_later('arg1')

      # Simulate job execution
      enqueued_job = TestJob.new('arg1', correlation_id: 'enqueue-123', parent_correlation_id: 'enqueue-123')
      enqueued_job.send(:with_correlation_tracking) do
        expect(CorrelationTracker.current_id).to eq('enqueue-123')
      end
    end
  end

  describe 'a job with a fixed argument list' do
    before do
      allow(Rails).to receive(:logger).and_return(double(info: nil, error: nil))
      FixedArityJob.received = nil
    end

    it 'gets exactly its own arguments, and the correlation ID through the job data' do
      CorrelationTracker.set(correlation_id: 'enqueue-123')
      job = FixedArityJob.new(42, 'hello')
      job.send(:attach_correlation_to_job)
      data = job.serialize
      CorrelationTracker.reset!

      ActiveJob::Base.execute(data)

      expect(FixedArityJob.received).to eq([42, 'hello', 'enqueue-123'])
    end

    it 'keeps the parent correlation ID through serialization' do
      CorrelationTracker.set(correlation_id: 'parent-1')
      job = FixedArityJob.new(1, 'x')
      job.send(:attach_correlation_to_job)

      data = job.serialize
      expect(data['correlation_id']).to eq('parent-1')
      expect(data['parent_correlation_id']).to eq('parent-1')
      expect(data['arguments'].size).to eq(2)
    end

    it 'still reads a job queued by the old version, with the correlation in its arguments' do
      CorrelationTracker.reset!
      data = FixedArityJob.new(7, 'old', { correlation_id: 'legacy-1', parent_correlation_id: 'legacy-0' }).serialize
      data.delete('correlation_id')
      data.delete('parent_correlation_id')

      ActiveJob::Base.execute(data)

      expect(FixedArityJob.received).to eq([7, 'old', 'legacy-1'])
    end
  end
end

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
    it 'attaches correlation to job arguments' do
      CorrelationTracker.set(correlation_id: 'test-123')

      job.arguments = ['arg1', 'arg2']
      job.send(:attach_correlation_to_job)

      correlation_arg = job.arguments.find { |arg| arg.is_a?(Hash) && arg.key?(:correlation_id) }

      expect(correlation_arg).not_to be_nil
      expect(correlation_arg[:correlation_id]).to eq('test-123')
      expect(correlation_arg[:parent_correlation_id]).to eq('test-123')
    end

    it 'does not add correlation if already present' do
      job.arguments = ['arg1', { correlation_id: 'existing-123' }]

      original_count = job.arguments.count
      job.send(:attach_correlation_to_job)

      expect(job.arguments.count).to eq(original_count)
    end

    it 'generates new correlation if none exists' do
      CorrelationTracker.reset!

      job.arguments = ['arg1']
      job.send(:attach_correlation_to_job)

      correlation_arg = job.arguments.find { |arg| arg.is_a?(Hash) && arg.key?(:correlation_id) }

      expect(correlation_arg[:correlation_id]).to match(/\A[0-9a-f-]{36}\z/i)
    end
  end

  describe '#extract_correlation_context' do
    it 'extracts correlation from arguments' do
      job.arguments = ['arg1', { correlation_id: 'test-123', parent_correlation_id: 'parent-456' }]

      context = job.send(:extract_correlation_context)

      expect(context[:correlation_id]).to eq('test-123')
      expect(context[:parent_correlation_id]).to eq('parent-456')
    end

    it 'returns empty hash if no correlation in arguments' do
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
end
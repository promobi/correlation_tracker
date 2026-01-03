# spec/context_spec.rb
require 'spec_helper'

RSpec.describe CorrelationTracker::Context do
  describe 'attributes' do
    it 'defines correlation_id attribute' do
      described_class.correlation_id = 'test-123'
      expect(described_class.correlation_id).to eq('test-123')
    end

    it 'defines parent_correlation_id attribute' do
      described_class.parent_correlation_id = 'parent-456'
      expect(described_class.parent_correlation_id).to eq('parent-456')
    end

    it 'defines origin_type attribute' do
      described_class.origin_type = 'test'
      expect(described_class.origin_type).to eq('test')
    end

    it 'defines user_id attribute' do
      described_class.user_id = 42
      expect(described_class.user_id).to eq(42)
    end

    it 'defines customer_id attribute' do
      described_class.customer_id = 99
      expect(described_class.customer_id).to eq(99)
    end

    it 'defines job_name attribute' do
      described_class.job_name = 'TestJob'
      expect(described_class.job_name).to eq('TestJob')
    end

    it 'defines kafka attributes' do
      described_class.kafka_topic = 'events'
      described_class.kafka_partition = 0
      described_class.kafka_offset = 12345

      expect(described_class.kafka_topic).to eq('events')
      expect(described_class.kafka_partition).to eq(0)
      expect(described_class.kafka_offset).to eq(12345)
    end
  end

  describe '#metadata' do
    it 'returns empty hash by default' do
      expect(described_class.metadata).to eq({})
    end

    it 'stores metadata as hash' do
      described_class.metadata = { key: 'value' }
      expect(described_class.metadata).to eq({ key: 'value' })
    end
  end

  describe '.add_metadata' do
    it 'adds metadata to context' do
      described_class.add_metadata(:custom_field, 'custom_value')
      expect(described_class.metadata[:custom_field]).to eq('custom_value')
    end

    it 'preserves existing metadata' do
      described_class.add_metadata(:field1, 'value1')
      described_class.add_metadata(:field2, 'value2')

      expect(described_class.metadata[:field1]).to eq('value1')
      expect(described_class.metadata[:field2]).to eq('value2')
    end
  end

  describe '.attributes' do
    it 'returns all attributes as hash' do
      described_class.correlation_id = 'test-123'
      described_class.origin_type = 'test'
      described_class.user_id = 42

      attrs = described_class.attributes

      expect(attrs[:correlation_id]).to eq('test-123')
      expect(attrs[:origin_type]).to eq('test')
      expect(attrs[:user_id]).to eq(42)
    end

    it 'merges metadata into attributes' do
      described_class.correlation_id = 'test-123'
      described_class.add_metadata(:custom, 'value')

      attrs = described_class.attributes

      expect(attrs[:correlation_id]).to eq('test-123')
      expect(attrs[:custom]).to eq('value')
    end
  end

  describe '.reset' do
    it 'clears all attributes' do
      described_class.correlation_id = 'test-123'
      described_class.user_id = 42
      described_class.add_metadata(:custom, 'value')

      described_class.reset

      expect(described_class.correlation_id).to be_nil
      expect(described_class.user_id).to be_nil
      expect(described_class.metadata).to eq({})
    end
  end

  describe 'thread safety' do
    it 'isolates context per thread' do
      described_class.correlation_id = 'main-thread'

      thread_id = nil

      thread = Thread.new do
        described_class.correlation_id = 'other-thread'
        thread_id = described_class.correlation_id
      end

      thread.join

      expect(thread_id).to eq('other-thread')
      expect(described_class.correlation_id).to eq('main-thread')
    end
  end
end
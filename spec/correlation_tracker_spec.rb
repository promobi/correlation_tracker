# spec/correlation_tracker_spec.rb
require 'spec_helper'

RSpec.describe CorrelationTracker do
  describe '.version' do
    it 'has a version number' do
      expect(CorrelationTracker::VERSION).not_to be nil
      expect(CorrelationTracker::VERSION).to match(/\d+\.\d+\.\d+/)
    end
  end

  describe '.configuration' do
    it 'returns a Configuration instance' do
      expect(CorrelationTracker.configuration).to be_a(CorrelationTracker::Configuration)
    end

    it 'returns the same instance on multiple calls' do
      config1 = CorrelationTracker.configuration
      config2 = CorrelationTracker.configuration
      expect(config1).to equal(config2)
    end
  end

  describe '.configure' do
    it 'yields configuration' do
      expect { |b| CorrelationTracker.configure(&b) }
        .to yield_with_args(CorrelationTracker::Configuration)
    end

    it 'allows setting configuration options' do
      CorrelationTracker.configure do |config|
        config.service_name = 'test-service'
      end

      expect(CorrelationTracker.configuration.service_name).to eq('test-service')
    end
  end

  describe '.generate_id' do
    it 'generates a valid UUID' do
      id = CorrelationTracker.generate_id
      expect(id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
    end

    it 'generates unique IDs' do
      ids = 100.times.map { CorrelationTracker.generate_id }
      expect(ids.uniq.size).to eq(100)
    end

    it 'uses configured ID generator' do
      custom_generator = -> { 'custom-id' }
      CorrelationTracker.configuration.id_generator = custom_generator

      expect(CorrelationTracker.generate_id).to eq('custom-id')
    end
  end

  describe '.set' do
    it 'sets correlation context' do
      correlation_id = CorrelationTracker.set(
        correlation_id: 'test-123',
        origin_type: 'test'
      )

      expect(correlation_id).to eq('test-123')
      expect(CorrelationTracker.current_id).to eq('test-123')
      expect(CorrelationTracker.origin_type).to eq('test')
    end

    it 'generates ID if not provided' do
      correlation_id = CorrelationTracker.set(origin_type: 'test')

      expect(correlation_id).not_to be_nil
      expect(CorrelationTracker.current_id).to eq(correlation_id)
      expect(correlation_id).to match(/\A[0-9a-f-]{36}\z/i)
    end

    it 'sets parent correlation ID' do
      CorrelationTracker.set(
        correlation_id: 'child-123',
        parent_id: 'parent-456'
      )

      expect(CorrelationTracker.current_id).to eq('child-123')
      expect(CorrelationTracker.parent_id).to eq('parent-456')
    end

    it 'sets additional metadata' do
      CorrelationTracker.set(
        correlation_id: 'test-123',
        user_id: 42,
        customer_id: 99
      )

      expect(CorrelationTracker::Context.user_id).to eq(42)
      expect(CorrelationTracker::Context.customer_id).to eq(99)
    end

    it 'uses default origin type if not provided' do
      CorrelationTracker.configuration.default_origin_type = 'default_type'
      CorrelationTracker.set(correlation_id: 'test-123')

      expect(CorrelationTracker.origin_type).to eq('default_type')
    end
  end

  describe '.current_id' do
    it 'returns current correlation ID' do
      CorrelationTracker.set(correlation_id: 'test-123')
      expect(CorrelationTracker.current_id).to eq('test-123')
    end

    it 'returns nil when not set' do
      expect(CorrelationTracker.current_id).to be_nil
    end
  end

  describe '.parent_id' do
    it 'returns parent correlation ID' do
      CorrelationTracker.set(parent_id: 'parent-456')
      expect(CorrelationTracker.parent_id).to eq('parent-456')
    end

    it 'returns nil when not set' do
      expect(CorrelationTracker.parent_id).to be_nil
    end
  end

  describe '.origin_type' do
    it 'returns origin type' do
      CorrelationTracker.set(origin_type: 'test')
      expect(CorrelationTracker.origin_type).to eq('test')
    end

    it 'returns nil when not set' do
      expect(CorrelationTracker.origin_type).to be_nil
    end
  end

  describe '.with_correlation' do
    it 'executes block with temporary correlation' do
      CorrelationTracker.set(correlation_id: 'original')

      result = CorrelationTracker.with_correlation(correlation_id: 'temporary') do
        expect(CorrelationTracker.current_id).to eq('temporary')
        'block_result'
      end

      expect(result).to eq('block_result')
      expect(CorrelationTracker.current_id).to eq('original')
    end

    it 'restores context even if block raises error' do
      CorrelationTracker.set(correlation_id: 'original')

      expect {
        CorrelationTracker.with_correlation(correlation_id: 'temporary') do
          raise 'test error'
        end
      }.to raise_error('test error')

      expect(CorrelationTracker.current_id).to eq('original')
    end

    it 'generates new ID if not provided' do
      result_id = nil

      CorrelationTracker.with_correlation do
        result_id = CorrelationTracker.current_id
      end

      expect(result_id).not_to be_nil
      expect(result_id).to match(/\A[0-9a-f-]{36}\z/i)
    end
  end

  describe '.to_h' do
    it 'returns all context as hash' do
      CorrelationTracker.set(
        correlation_id: 'test-123',
        parent_correlation_id: 'parent-456',
        origin_type: 'test',
        user_id: 42
      )

      hash = CorrelationTracker.to_h

      expect(hash[:correlation_id]).to eq('test-123')
      expect(hash[:parent_correlation_id]).to eq('parent-456')
      expect(hash[:origin_type]).to eq('test')
      expect(hash[:user_id]).to eq(42)
    end

    it 'excludes nil values' do
      CorrelationTracker.set(correlation_id: 'test-123')

      hash = CorrelationTracker.to_h

      expect(hash).to have_key(:correlation_id)
      expect(hash).not_to have_key(:parent_correlation_id)
      expect(hash).not_to have_key(:webhook_source)
    end

    it 'returns empty hash when nothing is set' do
      hash = CorrelationTracker.to_h
      expect(hash).to be_a(Hash)
      expect(hash).to be_empty
    end
  end

  describe '.reset!' do
    it 'clears all context' do
      CorrelationTracker.set(
        correlation_id: 'test-123',
        origin_type: 'test',
        user_id: 42
      )

      CorrelationTracker.reset!

      expect(CorrelationTracker.current_id).to be_nil
      expect(CorrelationTracker.origin_type).to be_nil
      expect(CorrelationTracker::Context.user_id).to be_nil
    end

    it 'is idempotent' do
      CorrelationTracker.reset!
      CorrelationTracker.reset!

      expect(CorrelationTracker.current_id).to be_nil
    end
  end

  describe '.add_metadata' do
    it 'adds custom metadata to context' do
      CorrelationTracker.set(correlation_id: 'test-123')
      CorrelationTracker.add_metadata(:custom_field, 'custom_value')

      hash = CorrelationTracker.to_h
      expect(hash[:custom_field]).to eq('custom_value')
    end

    it 'allows multiple metadata entries' do
      CorrelationTracker.set(correlation_id: 'test-123')
      CorrelationTracker.add_metadata(:field1, 'value1')
      CorrelationTracker.add_metadata(:field2, 'value2')

      hash = CorrelationTracker.to_h
      expect(hash[:field1]).to eq('value1')
      expect(hash[:field2]).to eq('value2')
    end
  end
end
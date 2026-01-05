# frozen_string_literal: true

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
      original_service_name = CorrelationTracker.configuration.service_name
      CorrelationTracker.configure do |config|
        config.service_name = 'test-service'
      end

      expect(CorrelationTracker.configuration.service_name).to eq('test-service')
    ensure
      CorrelationTracker.configuration.service_name = original_service_name
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
      original_generator = CorrelationTracker.configuration.id_generator
      custom_generator = -> { 'custom-id' }
      CorrelationTracker.configuration.id_generator = custom_generator

      expect(CorrelationTracker.generate_id).to eq('custom-id')
    ensure
      CorrelationTracker.configuration.id_generator = original_generator
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

      expect do
        CorrelationTracker.with_correlation(correlation_id: 'temporary') do
          raise 'test error'
        end
      end.to raise_error('test error')

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

    it 'restores all attributes after block, not just core ones' do
      CorrelationTracker.set(
        correlation_id: 'id-1',
        parent_id: 'parent-1',
        origin_type: 'origin-1',
        user_id: 100,
        customer_id: 'cust-1',
        job_name: 'OriginalJob'
      )

      CorrelationTracker.with_correlation(
        correlation_id: 'id-2',
        parent_id: 'parent-2',
        origin_type: 'origin-2',
        user_id: 200,
        customer_id: 'cust-2',
        job_name: 'TemporaryJob'
      ) do
        # Verify changes inside block
        expect(CorrelationTracker.current_id).to eq('id-2')
        expect(CorrelationTracker.parent_id).to eq('parent-2')
        expect(CorrelationTracker.origin_type).to eq('origin-2')
        expect(CorrelationTracker::Context.user_id).to eq(200)
        expect(CorrelationTracker::Context.customer_id).to eq('cust-2')
        expect(CorrelationTracker::Context.job_name).to eq('TemporaryJob')
      end

      # Verify ALL attributes are restored
      expect(CorrelationTracker.current_id).to eq('id-1')
      expect(CorrelationTracker.parent_id).to eq('parent-1')
      expect(CorrelationTracker.origin_type).to eq('origin-1')
      expect(CorrelationTracker::Context.user_id).to eq(100)
      expect(CorrelationTracker::Context.customer_id).to eq('cust-1')
      expect(CorrelationTracker::Context.job_name).to eq('OriginalJob')
    end

    it 'restores metadata after block' do
      CorrelationTracker.set(correlation_id: 'id-1')
      CorrelationTracker.add_metadata(:field1, 'value1')
      CorrelationTracker.add_metadata(:field2, 'value2')

      CorrelationTracker.with_correlation(correlation_id: 'id-2') do
        # Modify existing metadata
        CorrelationTracker.add_metadata(:field1, 'modified')
        # Add new metadata
        CorrelationTracker.add_metadata(:field3, 'new')

        hash = CorrelationTracker.to_h
        expect(hash[:field1]).to eq('modified')
        expect(hash[:field3]).to eq('new')
      end

      # Verify original metadata is restored
      hash = CorrelationTracker.to_h
      expect(hash[:field1]).to eq('value1')
      expect(hash[:field2]).to eq('value2')
      expect(hash[:field3]).to be_nil
    end

    it 'does not persist attributes set inside block that were not set before' do
      CorrelationTracker.reset!
      CorrelationTracker.set(correlation_id: 'id-1')

      CorrelationTracker.with_correlation(correlation_id: 'id-2') do
        # Set attribute that wasn't set before
        CorrelationTracker.set(user_id: 100, customer_id: 'cust-1')
        expect(CorrelationTracker::Context.user_id).to eq(100)
      end

      # After block: these attributes should be nil (not persisted)
      expect(CorrelationTracker.current_id).to eq('id-1')
      expect(CorrelationTracker::Context.user_id).to be_nil
      expect(CorrelationTracker::Context.customer_id).to be_nil
    end

    it 'handles nested with_correlation blocks correctly' do
      CorrelationTracker.set(correlation_id: 'outer', user_id: 1)

      CorrelationTracker.with_correlation(correlation_id: 'inner1', user_id: 2) do
        expect(CorrelationTracker.current_id).to eq('inner1')
        expect(CorrelationTracker::Context.user_id).to eq(2)

        CorrelationTracker.with_correlation(correlation_id: 'inner2', user_id: 3) do
          expect(CorrelationTracker.current_id).to eq('inner2')
          expect(CorrelationTracker::Context.user_id).to eq(3)
        end

        # Should restore to inner1 state
        expect(CorrelationTracker.current_id).to eq('inner1')
        expect(CorrelationTracker::Context.user_id).to eq(2)
      end

      # Should restore to outer state
      expect(CorrelationTracker.current_id).to eq('outer')
      expect(CorrelationTracker::Context.user_id).to eq(1)
    end

    it 'restores all context even when block raises exception' do
      CorrelationTracker.set(
        correlation_id: 'id-1',
        user_id: 100,
        customer_id: 'cust-1'
      )

      expect do
        CorrelationTracker.with_correlation(
          correlation_id: 'id-2',
          user_id: 200,
          customer_id: 'cust-2'
        ) do
          raise 'test error'
        end
      end.to raise_error('test error')

      # All attributes should be restored despite exception
      expect(CorrelationTracker.current_id).to eq('id-1')
      expect(CorrelationTracker::Context.user_id).to eq(100)
      expect(CorrelationTracker::Context.customer_id).to eq('cust-1')
    end
  end

  describe '.track_correlation' do
    it 'is an alias for with_correlation' do
      expect(CorrelationTracker.method(:track_correlation)).to eq(
        CorrelationTracker.method(:with_correlation)
      )
    end

    it 'works identically to with_correlation' do
      CorrelationTracker.set(
        correlation_id: 'id-1',
        user_id: 100
      )

      result = CorrelationTracker.track_correlation(
        correlation_id: 'id-2',
        user_id: 200
      ) do
        expect(CorrelationTracker.current_id).to eq('id-2')
        expect(CorrelationTracker::Context.user_id).to eq(200)
        'result'
      end

      expect(result).to eq('result')
      expect(CorrelationTracker.current_id).to eq('id-1')
      expect(CorrelationTracker::Context.user_id).to eq(100)
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

# spec/correlation_tracker_spec.rb
require 'spec_helper'

RSpec.describe CorrelationTracker do
  it 'has a version number' do
    expect(CorrelationTracker::VERSION).not_to be nil
  end

  describe '.configuration' do
    it 'returns a Configuration instance' do
      expect(CorrelationTracker.configuration).to be_a(CorrelationTracker::Configuration)
    end
  end

  describe '.configure' do
    it 'yields configuration' do
      expect { |b| CorrelationTracker.configure(&b) }.to yield_with_args(CorrelationTracker::Configuration)
    end
  end

  describe '.generate_id' do
    it 'generates a UUID' do
      id = CorrelationTracker.generate_id
      expect(id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
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

      expect(hash).not_to have_key(:parent_correlation_id)
      expect(hash).not_to have_key(:webhook_source)
    end
  end

  describe '.reset!' do
    it 'clears all context' do
      CorrelationTracker.set(correlation_id: 'test-123', origin_type: 'test')

      CorrelationTracker.reset!

      expect(CorrelationTracker.current_id).to be_nil
      expect(CorrelationTracker.origin_type).to be_nil
    end
  end
end
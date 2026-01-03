# spec/integrations/lograge_spec.rb
require 'spec_helper'

RSpec.describe CorrelationTracker::Integrations::Lograge do
  describe '.setup' do
    before do
      skip 'Lograge not loaded' unless defined?(Lograge)
    end

    it 'configures Lograge custom_options' do
      described_class.setup

      expect(Lograge.custom_options).to be_a(Proc)
    end

    it 'includes correlation context in custom options' do
      described_class.setup

      CorrelationTracker.set(
        correlation_id: 'test-123',
        origin_type: 'http'
      )

      event = OpenStruct.new(
        duration: 100.5,
        payload: {
          db_runtime: 50.2
        }
      )

      options = Lograge.custom_options.call(event)

      expect(options[:correlation_id]).to eq('test-123')
      expect(options[:origin_type]).to eq('http')
      expect(options[:service_name]).to eq(CorrelationTracker.configuration.service_name)
      expect(options[:timestamp]).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it 'includes performance metrics' do
      described_class.setup

      event = OpenStruct.new(
        duration: 100.5,
        payload: {
          db_runtime: 50.2,
          view_runtime: 25.1
        }
      )

      options = Lograge.custom_options.call(event)

      expect(options[:duration_ms]).to eq(100.5)
      expect(options[:db_runtime_ms]).to eq(50.2)
      expect(options[:view_runtime_ms]).to eq(25.1)
    end

    it 'compacts nil values' do
      described_class.setup

      CorrelationTracker.set(correlation_id: 'test-123')

      event = OpenStruct.new(
        duration: nil,
        payload: {}
      )

      options = Lograge.custom_options.call(event)

      expect(options).not_to have_key(:duration_ms)
      expect(options).not_to have_key(:db_runtime_ms)
    end
  end
end
# spec/configuration_spec.rb
require 'spec_helper'

RSpec.describe CorrelationTracker::Configuration do
  subject(:config) { described_class.new }

  describe '#initialize' do
    it 'sets default values' do
      expect(config.enabled).to be true
      expect(config.header_name).to eq('X-Correlation-ID')
      expect(config.parent_header_name).to eq('X-Parent-Correlation-ID')
      expect(config.fallback_headers).to eq(['X-Request-ID', 'X-Trace-ID'])
      expect(config.default_origin_type).to eq('http')
      expect(config.log_level).to eq(:info)
      expect(config.propagate_to_http_clients).to be true
      expect(config.validate_uuid_format).to be true
    end

    it 'sets default id_generator' do
      expect(config.id_generator).to be_a(Proc)
      id = config.id_generator.call
      expect(id).to match(/\A[0-9a-f-]{36}\z/i)
    end

    it 'sets default integrations' do
      expect(config.integrations[:action_controller]).to be true
      expect(config.integrations[:active_job]).to be true
      expect(config.integrations[:lograge]).to be true
      expect(config.integrations[:sidekiq]).to be true
      expect(config.integrations[:kafka]).to be true
      expect(config.integrations[:http_clients]).to be true
      expect(config.integrations[:opentelemetry]).to be false
    end

    it 'sets Kafka header keys' do
      expect(config.kafka_header_key).to eq('correlation_id')
      expect(config.kafka_parent_header_key).to eq('parent_correlation_id')
    end
  end

  describe '#enable_integration' do
    it 'enables an integration' do
      config.disable_integration(:sidekiq)
      config.enable_integration(:sidekiq)

      expect(config.integrations[:sidekiq]).to be true
    end

    it 'accepts string argument' do
      config.enable_integration('sidekiq')
      expect(config.integrations[:sidekiq]).to be true
    end
  end

  describe '#disable_integration' do
    it 'disables an integration' do
      config.disable_integration(:sidekiq)
      expect(config.integrations[:sidekiq]).to be false
    end

    it 'accepts string argument' do
      config.disable_integration('sidekiq')
      expect(config.integrations[:sidekiq]).to be false
    end
  end

  describe '#integration_enabled?' do
    it 'returns true for enabled integration' do
      expect(config.integration_enabled?(:action_controller)).to be true
    end

    it 'returns false for disabled integration' do
      config.disable_integration(:sidekiq)
      expect(config.integration_enabled?(:sidekiq)).to be false
    end

    it 'accepts string argument' do
      expect(config.integration_enabled?('action_controller')).to be true
    end
  end

  describe 'customization' do
    it 'allows changing header name' do
      config.header_name = 'X-Custom-Correlation'
      expect(config.header_name).to eq('X-Custom-Correlation')
    end

    it 'allows changing ID generator' do
      custom_generator = -> { 'custom-id' }
      config.id_generator = custom_generator

      expect(config.id_generator.call).to eq('custom-id')
    end

    it 'allows changing service name' do
      config.service_name = 'custom-service'
      expect(config.service_name).to eq('custom-service')
    end

    it 'allows adding fallback headers' do
      config.fallback_headers << 'X-Custom-Header'
      expect(config.fallback_headers).to include('X-Custom-Header')
    end
  end
end
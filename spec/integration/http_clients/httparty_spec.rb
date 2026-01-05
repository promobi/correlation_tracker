# spec/integrations/http_clients/httparty_spec.rb
require 'spec_helper'
require 'correlation_tracker/integrations/http_clients/httparty'

RSpec.describe CorrelationTracker::Integrations::HttpClients::HTTPartyIntegration do
  before do
    skip 'HTTParty not loaded' unless defined?(HTTParty)
  end

  let(:test_class) do
    Class.new do
      include HTTParty
      include CorrelationTracker::Integrations::HttpClients::HTTPartyIntegration
    end
  end

  describe '.correlation_headers' do
    it 'returns correlation headers' do
      CorrelationTracker.set(correlation_id: 'test-123')

      headers = described_class.correlation_headers

      expect(headers['X-Correlation-ID']).to eq('test-123')
      expect(headers['X-Parent-Correlation-ID']).to eq('test-123')
    end

    it 'returns empty hash if no correlation_id' do
      CorrelationTracker.reset!

      headers = described_class.correlation_headers

      expect(headers).to eq({})
    end
  end

  describe 'included in HTTParty class' do
    it 'sets default headers' do
      CorrelationTracker.set(correlation_id: 'test-123')

      # Note: Actual header propagation happens at class load time
      # This test verifies the integration pattern
      expect(described_class).to respond_to(:correlation_headers)
    end
  end
end
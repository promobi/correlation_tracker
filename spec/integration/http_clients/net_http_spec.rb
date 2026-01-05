# spec/integrations/http_clients/net_http_spec.rb
require 'spec_helper'
require 'net/http'
require 'correlation_tracker/integrations/http_clients/net_http'

RSpec.describe CorrelationTracker::Integrations::HttpClients::NetHTTPExtension do
  let(:http) { Net::HTTP.new('example.com', 80) }
  let(:request) { Net::HTTP::Get.new('/test') }

  describe '#request' do
    before do
      # Stub actual HTTP request
      allow(http).to receive(:transport_request).and_return(
        Net::HTTPResponse.new('1.1', '200', 'OK')
      )
    end

    it 'adds correlation headers to request' do
      CorrelationTracker.set(correlation_id: 'test-123')
      CorrelationTracker.configuration.propagate_to_http_clients = true

      http.request(request)

      expect(request['X-Correlation-ID']).to eq('test-123')
      expect(request['X-Parent-Correlation-ID']).to eq('test-123')
    end

    it 'does not add headers if no correlation_id' do
      CorrelationTracker.reset!

      http.request(request)

      expect(request['X-Correlation-ID']).to be_nil
    end

    it 'does not add headers when propagation disabled' do
      CorrelationTracker.set(correlation_id: 'test-123')
      CorrelationTracker.configuration.propagate_to_http_clients = false

      http.request(request)

      expect(request['X-Correlation-ID']).to be_nil

      # Reset
      CorrelationTracker.configuration.propagate_to_http_clients = true
    end
  end

  describe 'patching Net::HTTP' do
    it 'prepends extension module' do
      expect(Net::HTTP.ancestors).to include(described_class)
    end
  end
end
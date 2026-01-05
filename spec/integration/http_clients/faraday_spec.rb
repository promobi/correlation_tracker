# spec/integrations/http_clients/faraday_spec.rb
require 'spec_helper'

begin
  require 'faraday'
  require 'correlation_tracker/integrations/http_clients/faraday'
rescue LoadError
  # Faraday not available
end

RSpec.describe CorrelationTracker::Integrations::HttpClients::FaradayMiddleware do
  let(:app) { double('app') }
  let(:middleware) { described_class.new(app) }
  let(:env) { Faraday::Env.new }

  before do
    skip 'Faraday not loaded' unless defined?(Faraday)

    env.url = URI('http://example.com/test')
    env.request_headers = {}
  end

  describe '#call' do
    context 'when propagation is enabled' do
      before do
        CorrelationTracker.configuration.propagate_to_http_clients = true
      end

      it 'adds correlation headers to request' do
        CorrelationTracker.set(correlation_id: 'test-123')

        allow(app).to receive(:call).with(env)

        middleware.call(env)

        expect(env.request_headers['X-Correlation-ID']).to eq('test-123')
        expect(env.request_headers['X-Parent-Correlation-ID']).to eq('test-123')
      end

      it 'does not add headers if no correlation_id' do
        CorrelationTracker.reset!

        allow(app).to receive(:call).with(env)

        middleware.call(env)

        expect(env.request_headers['X-Correlation-ID']).to be_nil
      end

      it 'calls next middleware' do
        expect(app).to receive(:call).with(env)

        middleware.call(env)
      end
    end

    context 'when propagation is disabled' do
      before do
        CorrelationTracker.configuration.propagate_to_http_clients = false
      end

      after do
        CorrelationTracker.configuration.propagate_to_http_clients = true
      end

      it 'does not add correlation headers' do
        CorrelationTracker.set(correlation_id: 'test-123')

        allow(app).to receive(:call).with(env)

        middleware.call(env)

        expect(env.request_headers['X-Correlation-ID']).to be_nil
      end
    end
  end

  describe 'registration' do
    it 'registers middleware with Faraday' do
      skip 'Faraday not loaded' unless defined?(Faraday)

      expect(Faraday::Request.registered_middleware[:correlation_tracker]).to eq(described_class)
    end
  end

  describe 'integration test' do
    it 'propagates correlation through Faraday request' do
      skip 'Faraday not loaded' unless defined?(Faraday)

      CorrelationTracker.set(correlation_id: 'integration-test-123')

      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.get('/test') do |env|
          expect(env.request_headers['X-Correlation-ID']).to eq('integration-test-123')
          [200, {}, 'OK']
        end
      end

      connection = Faraday.new do |f|
        f.request :correlation_tracker
        f.adapter :test, stubs
      end

      connection.get('/test')

      stubs.verify_stubbed_calls
    end
  end
end
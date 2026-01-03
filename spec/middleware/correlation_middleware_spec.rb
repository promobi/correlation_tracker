# spec/middleware/correlation_middleware_spec.rb
require 'spec_helper'

RSpec.describe CorrelationTracker::Middleware::CorrelationMiddleware do
  include Rack::Test::Methods

  let(:app) { ->(env) { [200, {}, ['OK']] } }
  let(:middleware) { described_class.new(app) }

  def make_request(path = '/', headers = {})
    env = Rack::MockRequest.env_for(path, headers)
    middleware.call(env)
  end

  describe '#call' do
    it 'sets correlation ID from header' do
      make_request('/', 'HTTP_X_CORRELATION_ID' => 'test-123')

      expect(CorrelationTracker.current_id).to eq('test-123')
    end

    it 'generates correlation ID if not present' do
      make_request('/')

      expect(CorrelationTracker.current_id).not_to be_nil
      expect(CorrelationTracker.current_id).to match(/\A[0-9a-f-]{36}\z/i)
    end

    it 'extracts parent correlation ID' do
      make_request('/', {
        'HTTP_X_CORRELATION_ID' => 'child-123',
        'HTTP_X_PARENT_CORRELATION_ID' => 'parent-456'
      })

      expect(CorrelationTracker.current_id).to eq('child-123')
      expect(CorrelationTracker.parent_id).to eq('parent-456')
    end

    it 'tries fallback headers' do
      make_request('/', 'HTTP_X_REQUEST_ID' => 'fallback-123')

      expect(CorrelationTracker.current_id).to eq('fallback-123')
    end

    it 'echoes correlation ID in response headers' do
      status, headers, body = make_request('/', 'HTTP_X_CORRELATION_ID' => 'test-123')

      expect(headers['X-Correlation-ID']).to eq('test-123')
    end

    it 'resets context after request' do
      make_request('/', 'HTTP_X_CORRELATION_ID' => 'test-123')

      # After request completes
      expect(CorrelationTracker.current_id).to be_nil
    end

    it 'determines origin type for webhooks' do
      make_request('/webhooks/stripe')

      expect(CorrelationTracker.origin_type).to eq('webhook')
    end

    it 'determines origin type for email links' do
      make_request('/verify')

      expect(CorrelationTracker.origin_type).to eq('email_link')
    end

    it 'defaults to http origin type' do
      make_request('/api/orders')

      expect(CorrelationTracker.origin_type).to eq('api')
    end

    it 'stores correlation ID in env' do
      env = Rack::MockRequest.env_for('/')
      middleware.call(env)

      expect(env['correlation_tracker.id']).not_to be_nil
      expect(env['correlation_tracker.origin_type']).not_to be_nil
    end
  end

  describe 'when disabled' do
    before do
      CorrelationTracker.configuration.enabled = false
    end

    after do
      CorrelationTracker.configuration.enabled = true
    end

    it 'skips correlation tracking' do
      make_request('/')

      expect(CorrelationTracker.current_id).to be_nil
    end
  end

  describe 'UUID validation' do
    context 'when validation enabled' do
      it 'accepts valid UUIDs' do
        make_request('/', 'HTTP_X_CORRELATION_ID' => '550e8400-e29b-41d4-a716-446655440000')

        expect(CorrelationTracker.current_id).to eq('550e8400-e29b-41d4-a716-446655440000')
      end

      it 'rejects invalid UUIDs and generates new one' do
        make_request('/', 'HTTP_X_CORRELATION_ID' => 'invalid-uuid')

        expect(CorrelationTracker.current_id).not_to eq('invalid-uuid')
        expect(CorrelationTracker.current_id).to match(/\A[0-9a-f-]{36}\z/i)
      end
    end

    context 'when validation disabled' do
      before do
        CorrelationTracker.configuration.validate_uuid_format = false
      end

      after do
        CorrelationTracker.configuration.validate_uuid_format = true
      end

      it 'accepts any correlation ID' do
        make_request('/', 'HTTP_X_CORRELATION_ID' => 'custom-id-123')

        expect(CorrelationTracker.current_id).to eq('custom-id-123')
      end
    end
  end
end
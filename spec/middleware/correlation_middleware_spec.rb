# spec/middleware/correlation_middleware_spec.rb
require 'spec_helper'

RSpec.describe CorrelationTracker::Middleware::CorrelationMiddleware do
  include Rack::Test::Methods

  let(:captured_correlation) { {} }
  let(:app) do
    ->(env) do
      # Capture correlation during request processing
      captured_correlation[:id] = CorrelationTracker.current_id
      captured_correlation[:parent_id] = CorrelationTracker.parent_id
      captured_correlation[:origin_type] = CorrelationTracker.origin_type
      [200, {}, ['OK']]
    end
  end
  let(:middleware) { described_class.new(app) }

  def make_request(path = '/', headers = {})
    env = Rack::MockRequest.env_for(path, headers)
    captured_correlation.clear
    middleware.call(env)
  end

  describe '#call' do
    it 'sets correlation ID from header' do
      test_uuid = '550e8400-e29b-41d4-a716-446655440000'
      make_request('/', 'HTTP_X_CORRELATION_ID' => test_uuid)

      expect(captured_correlation[:id]).to eq(test_uuid)
    end

    it 'generates correlation ID if not present' do
      make_request('/')

      expect(captured_correlation[:id]).not_to be_nil
      expect(captured_correlation[:id]).to match(/\A[0-9a-f-]{36}\z/i)
    end

    it 'extracts parent correlation ID' do
      child_uuid = '550e8400-e29b-41d4-a716-446655440001'
      parent_uuid = '550e8400-e29b-41d4-a716-446655440002'
      make_request('/', {
        'HTTP_X_CORRELATION_ID' => child_uuid,
        'HTTP_X_PARENT_CORRELATION_ID' => parent_uuid
      })

      expect(captured_correlation[:id]).to eq(child_uuid)
      expect(captured_correlation[:parent_id]).to eq(parent_uuid)
    end

    it 'tries fallback headers' do
      fallback_uuid = '550e8400-e29b-41d4-a716-446655440003'
      make_request('/', 'HTTP_X_REQUEST_ID' => fallback_uuid)

      expect(captured_correlation[:id]).to eq(fallback_uuid)
    end

    it 'echoes correlation ID in response headers' do
      test_uuid = '550e8400-e29b-41d4-a716-446655440004'
      status, headers, body = make_request('/', 'HTTP_X_CORRELATION_ID' => test_uuid)

      expect(headers['X-Correlation-ID']).to eq(test_uuid)
    end

    it 'resets context after request' do
      test_uuid = '550e8400-e29b-41d4-a716-446655440005'
      make_request('/', 'HTTP_X_CORRELATION_ID' => test_uuid)

      # After request completes
      expect(CorrelationTracker.current_id).to be_nil
    end

    it 'determines origin type for webhooks' do
      make_request('/webhooks/stripe')

      expect(captured_correlation[:origin_type]).to eq('webhook')
    end

    it 'determines origin type for email links' do
      make_request('/verify')

      expect(captured_correlation[:origin_type]).to eq('email_link')
    end

    it 'defaults to http origin type' do
      make_request('/api/orders')

      expect(captured_correlation[:origin_type]).to eq('api')
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

        expect(captured_correlation[:id]).to eq('550e8400-e29b-41d4-a716-446655440000')
      end

      it 'rejects invalid UUIDs and generates new one' do
        make_request('/', 'HTTP_X_CORRELATION_ID' => 'invalid-uuid')

        expect(captured_correlation[:id]).not_to eq('invalid-uuid')
        expect(captured_correlation[:id]).to match(/\A[0-9a-f-]{36}\z/i)
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

        expect(captured_correlation[:id]).to eq('custom-id-123')
      end
    end
  end
end
# spec/extractors/http_extractor_spec.rb
require 'spec_helper'

RSpec.describe CorrelationTracker::Extractors::HttpExtractor do
  subject { described_class.new }

  let(:extractor) { described_class.new }
  let(:request) do
    instance_double('Rack::Request').tap do |r|
      allow(r).to receive(:env).and_return({})
      allow(r).to receive(:path).and_return('/')
    end
  end

  describe '#extract' do
    it_behaves_like 'an extractor'

    it 'extracts correlation ID from header' do
      allow(request).to receive(:env).and_return({
                                                   'HTTP_X_CORRELATION_ID' => '550e8400-e29b-41d4-a716-446655440000'
                                                 })
      allow(request).to receive(:path).and_return('/')

      result = extractor.extract(request)

      expect(result[:correlation_id]).to eq('550e8400-e29b-41d4-a716-446655440000')
    end

    it 'extracts parent correlation ID' do
      allow(request).to receive(:env).and_return({
                                                   'HTTP_X_PARENT_CORRELATION_ID' => 'parent-456'
                                                 })
      allow(request).to receive(:path).and_return('/')

      result = extractor.extract(request)

      expect(result[:parent_correlation_id]).to eq('parent-456')
    end

    it 'determines origin type as api for /api paths' do
      allow(request).to receive(:env).and_return({})
      allow(request).to receive(:path).and_return('/api/orders')

      result = extractor.extract(request)

      expect(result[:origin_type]).to eq('api')
    end

    it 'determines origin type as webhook for /webhooks paths' do
      allow(request).to receive(:env).and_return({})
      allow(request).to receive(:path).and_return('/webhooks/stripe')

      result = extractor.extract(request)

      expect(result[:origin_type]).to eq('webhook')
    end

    it 'defaults to http origin type' do
      allow(request).to receive(:env).and_return({})
      allow(request).to receive(:path).and_return('/orders')

      result = extractor.extract(request)

      expect(result[:origin_type]).to eq('http')
    end

    it 'tries fallback headers' do
      fallback_uuid = '550e8400-e29b-41d4-a716-446655440010'
      allow(request).to receive(:env).and_return({
                                                   'HTTP_X_REQUEST_ID' => fallback_uuid
                                                 })
      allow(request).to receive(:path).and_return('/')

      result = extractor.extract(request)

      expect(result[:correlation_id]).to eq(fallback_uuid)
    end
  end
end
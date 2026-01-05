# spec/extractors/webhook_extractor_spec.rb
require 'spec_helper'

RSpec.describe CorrelationTracker::Extractors::WebhookExtractor do
  subject { described_class.new }

  let(:extractor) { described_class.new }
  let(:request) do
    instance_double('Rack::Request').tap do |r|
      allow(r).to receive(:env).and_return({})
      allow(r).to receive(:path).and_return('/webhooks/stripe')
    end
  end

  describe '#extract' do
    it_behaves_like 'an extractor'

    it 'sets origin type to webhook' do
      allow(request).to receive(:env).and_return({})
      allow(request).to receive(:path).and_return('/webhooks/stripe')

      result = extractor.extract(request)

      expect(result[:origin_type]).to eq('webhook')
    end

    it 'detects Stripe webhooks from path' do
      allow(request).to receive(:env).and_return({})
      allow(request).to receive(:path).and_return('/webhooks/stripe')

      result = extractor.extract(request)

      expect(result[:webhook_source]).to eq('stripe')
    end

    it 'detects GitHub webhooks from header' do
      allow(request).to receive(:env).and_return({
                                                   'HTTP_X_GITHUB_EVENT' => 'push'
                                                 })
      allow(request).to receive(:path).and_return('/webhooks')

      result = extractor.extract(request)

      expect(result[:webhook_source]).to eq('github')
    end

    it 'detects Shopify webhooks from header' do
      allow(request).to receive(:env).and_return({
                                                   'HTTP_X_SHOPIFY_HMAC_SHA256' => 'signature'
                                                 })
      allow(request).to receive(:path).and_return('/webhooks')

      result = extractor.extract(request)

      expect(result[:webhook_source]).to eq('shopify')
    end

    it 'extracts external request ID from GitHub' do
      allow(request).to receive(:env).and_return({
                                                   'HTTP_X_GITHUB_DELIVERY' => 'github-123'
                                                 })
      allow(request).to receive(:path).and_return('/webhooks')

      result = extractor.extract(request)

      expect(result[:external_request_id]).to eq('github-123')
    end

    it 'extracts external request ID from Stripe signature' do
      allow(request).to receive(:env).and_return({
                                                   'HTTP_STRIPE_SIGNATURE' => 't=123,v1=abc'
                                                 })
      allow(request).to receive(:path).and_return('/webhooks')

      result = extractor.extract(request)

      expect(result[:external_request_id]).to eq('t=123')
    end

    it 'defaults to unknown webhook source' do
      allow(request).to receive(:env).and_return({})
      allow(request).to receive(:path).and_return('/webhooks')

      result = extractor.extract(request)

      expect(result[:webhook_source]).to eq('unknown')
    end
  end
end
# spec/extractors/email_link_extractor_spec.rb
require 'spec_helper'

RSpec.describe CorrelationTracker::Extractors::EmailLinkExtractor do
  let(:extractor) { described_class.new }
  let(:request) { instance_double('Rack::Request') }

  describe '#extract' do
    it_behaves_like 'an extractor'

    it 'sets origin type to email_link' do
      allow(request).to receive(:env).and_return({})
      allow(request).to receive(:path).and_return('/verify')
      allow(request).to receive(:params).and_return({})

      result = extractor.extract(request)

      expect(result[:origin_type]).to eq('email_link')
    end

    it 'detects email verification type' do
      allow(request).to receive(:env).and_return({})
      allow(request).to receive(:path).and_return('/verify')
      allow(request).to receive(:params).and_return({})

      result = extractor.extract(request)

      expect(result[:email_type]).to eq('email_verification')
    end

    it 'detects password reset type' do
      allow(request).to receive(:env).and_return({})
      allow(request).to receive(:path).and_return('/reset')
      allow(request).to receive(:params).and_return({})

      result = extractor.extract(request)

      expect(result[:email_type]).to eq('password_reset')
    end

    it 'detects invitation type' do
      allow(request).to receive(:env).and_return({})
      allow(request).to receive(:path).and_return('/invite')
      allow(request).to receive(:params).and_return({})

      result = extractor.extract(request)

      expect(result[:email_type]).to eq('invitation')
    end

    it 'detects confirmation type' do
      allow(request).to receive(:env).and_return({})
      allow(request).to receive(:path).and_return('/confirm')
      allow(request).to receive(:params).and_return({})

      result = extractor.extract(request)

      expect(result[:email_type]).to eq('confirmation')
    end

    it 'defaults to unknown email type' do
      allow(request).to receive(:env).and_return({})
      allow(request).to receive(:path).and_return('/other')
      allow(request).to receive(:params).and_return({})

      result = extractor.extract(request)

      expect(result[:email_type]).to eq('unknown')
    end
  end
end
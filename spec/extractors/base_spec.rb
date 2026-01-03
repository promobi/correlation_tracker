# spec/extractors/base_spec.rb
require 'spec_helper'

RSpec.describe CorrelationTracker::Extractors::Base do
  let(:request) { instance_double('Rack::Request') }

  describe '#extract' do
    it 'raises NotImplementedError' do
      extractor = described_class.new

      expect {
        extractor.extract(request)
      }.to raise_error(NotImplementedError)
    end
  end

  describe 'protected methods' do
    let(:extractor) { described_class.new }

    describe '#extract_header' do
      it 'extracts header from Rack env' do
        allow(request).to receive(:env).and_return({
                                                     'HTTP_X_CORRELATION_ID' => 'test-123'
                                                   })

        result = extractor.send(:extract_header, request, 'X-Correlation-ID')
        expect(result).to eq('test-123')
      end

      it 'returns nil for missing header' do
        allow(request).to receive(:env).and_return({})

        result = extractor.send(:extract_header, request, 'X-Missing-Header')
        expect(result).to be_nil
      end

      it 'converts header name to Rack format' do
        allow(request).to receive(:env).and_return({
                                                     'HTTP_X_CUSTOM_HEADER' => 'value'
                                                   })

        result = extractor.send(:extract_header, request, 'X-Custom-Header')
        expect(result).to eq('value')
      end
    end

    describe '#valid_uuid?' do
      context 'when validation enabled' do
        it 'returns true for valid UUIDs' do
          expect(extractor.send(:valid_uuid?, '550e8400-e29b-41d4-a716-446655440000')).to be true
        end

        it 'returns false for invalid UUIDs' do
          expect(extractor.send(:valid_uuid?, 'invalid')).to be false
        end

        it 'returns false for nil' do
          expect(extractor.send(:valid_uuid?, nil)).to be false
        end
      end

      context 'when validation disabled' do
        before do
          CorrelationTracker.configuration.validate_uuid_format = false
        end

        after do
          CorrelationTracker.configuration.validate_uuid_format = true
        end

        it 'returns false for validation check' do
          expect(extractor.send(:valid_uuid?, 'anything')).to be false
        end
      end
    end
  end
end
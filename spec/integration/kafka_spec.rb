# spec/integrations/kafka_spec.rb
require 'spec_helper'
require 'correlation_tracker/integrations/kafka'

# Define a minimal Rails stub for testing
unless defined?(Rails)
  module Rails
    def self.logger
      @logger ||= Logger.new(nil)
    end

    def self.logger=(logger)
      @logger = logger
    end
  end
end

RSpec.describe CorrelationTracker::Integrations::Kafka do
  describe 'ProducerInterceptor' do
    let(:interceptor) { described_class::ProducerInterceptor.new }
    let(:message) { OpenStruct.new(headers: {}) }

    describe '#call' do
      it 'adds correlation_id to message headers' do
        CorrelationTracker.set(correlation_id: 'test-123')

        interceptor.call(message) { }

        expect(message.headers['correlation_id']).to eq('test-123')
        expect(message.headers['parent_correlation_id']).to eq('test-123')
      end

      it 'adds origin_type to headers' do
        CorrelationTracker.set(correlation_id: 'test-123', origin_type: 'http')

        interceptor.call(message) { }

        expect(message.headers['origin_type']).to eq('http')
      end

      it 'adds service_name to headers' do
        interceptor.call(message) { }

        expect(message.headers['service_name']).to eq(CorrelationTracker.configuration.service_name)
      end

      it 'initializes headers if nil' do
        message.headers = nil
        CorrelationTracker.set(correlation_id: 'test-123')

        interceptor.call(message) { }

        expect(message.headers).to be_a(Hash)
        expect(message.headers['correlation_id']).to eq('test-123')
      end

      it 'does not add headers if no correlation_id' do
        CorrelationTracker.reset!

        interceptor.call(message) { }

        expect(message.headers['correlation_id']).to be_nil
      end

      it 'yields to next handler' do
        expect { |b| interceptor.call(message, &b) }.to yield_with_args(message)
      end
    end
  end

  describe 'ConsumerInterceptor' do
    let(:interceptor) { described_class::ConsumerInterceptor.new }
    let(:message) do
      OpenStruct.new(
        headers: {
          'correlation_id' => 'test-123',
          'parent_correlation_id' => 'parent-456'
        },
        topic: 'events',
        partition: 0,
        offset: 12345
      )
    end

    before do
      allow(Rails).to receive(:logger).and_return(double(info: nil, error: nil))
    end

    describe '#call' do
      it 'sets correlation context from message headers' do
        interceptor.call(message) do
          expect(CorrelationTracker.current_id).to eq('test-123')
          expect(CorrelationTracker.parent_id).to eq('parent-456')
          expect(CorrelationTracker.origin_type).to eq('kafka_consumer')
        end
      end

      it 'sets Kafka context' do
        interceptor.call(message) do
          expect(CorrelationTracker::Context.kafka_topic).to eq('events')
          expect(CorrelationTracker::Context.kafka_partition).to eq(0)
          expect(CorrelationTracker::Context.kafka_offset).to eq(12345)
        end
      end

      it 'generates correlation_id if not in headers' do
        message.headers = {}

        interceptor.call(message) do
          expect(CorrelationTracker.current_id).to match(/\A[0-9a-f-]{36}\z/i)
        end
      end

      it 'logs message consumption' do
        expect(Rails.logger).to receive(:info) do |hash|
          expect(hash[:message]).to eq('Kafka message consumed')
          expect(hash[:topic]).to eq('events')
          expect(hash[:partition]).to eq(0)
          expect(hash[:offset]).to eq(12345)
        end

        interceptor.call(message) { }
      end

      it 'logs message processing completion' do
        expect(Rails.logger).to receive(:info).with(
          hash_including(message: 'Kafka message processed')
        )

        interceptor.call(message) { }
      end

      it 'logs errors' do
        expect(Rails.logger).to receive(:error) do |hash|
          expect(hash[:message]).to eq('Kafka message processing failed')
          expect(hash[:error_class]).to eq('RuntimeError')
        end

        expect {
          interceptor.call(message) do
            raise 'Test error'
          end
        }.to raise_error('Test error')
      end

      it 'resets context after processing' do
        interceptor.call(message) { }

        expect(CorrelationTracker.current_id).to be_nil
      end
    end
  end

  describe 'Helpers' do
    let(:helper_class) do
      Class.new do
        include CorrelationTracker::Integrations::Kafka::Helpers
      end
    end

    let(:helper) { helper_class.new }

    describe '#add_correlation_headers' do
      it 'adds correlation to headers' do
        CorrelationTracker.set(correlation_id: 'test-123', origin_type: 'http')

        headers = helper.add_correlation_headers

        expect(headers['correlation_id']).to eq('test-123')
        expect(headers['parent_correlation_id']).to eq('test-123')
        expect(headers['origin_type']).to eq('http')
      end

      it 'merges with existing headers' do
        CorrelationTracker.set(correlation_id: 'test-123')

        headers = helper.add_correlation_headers('custom' => 'value')

        expect(headers['correlation_id']).to eq('test-123')
        expect(headers['custom']).to eq('value')
      end

      it 'generates correlation_id if not present' do
        CorrelationTracker.reset!

        headers = helper.add_correlation_headers

        expect(headers['correlation_id']).to match(/\A[0-9a-f-]{36}\z/i)
      end
    end

    describe '#extract_correlation_from_headers' do
      it 'extracts correlation from headers' do
        headers = {
          'correlation_id' => 'test-123',
          'parent_correlation_id' => 'parent-456'
        }

        result = helper.extract_correlation_from_headers(headers)

        expect(result[:correlation_id]).to eq('test-123')
        expect(result[:parent_correlation_id]).to eq('parent-456')
      end

      it 'handles missing headers' do
        result = helper.extract_correlation_from_headers({})

        expect(result[:correlation_id]).to be_nil
        expect(result[:parent_correlation_id]).to be_nil
      end
    end
  end
end
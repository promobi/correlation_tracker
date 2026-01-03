# spec/utilities/logger_spec.rb
require 'spec_helper'

RSpec.describe CorrelationTracker::Utilities::Logger do
  let(:mock_logger) { instance_double('Logger') }
  let(:logger) { described_class.new(mock_logger) }

  before do
    allow(mock_logger).to receive(:debug)
    allow(mock_logger).to receive(:info)
    allow(mock_logger).to receive(:warn)
    allow(mock_logger).to receive(:error)
    allow(mock_logger).to receive(:fatal)
  end

  describe '#initialize' do
    it 'accepts a logger' do
      expect { described_class.new(mock_logger) }.not_to raise_error
    end

    it 'uses Rails logger by default if available' do
      skip 'Rails not loaded' unless defined?(Rails)

      logger = described_class.new
      expect(logger.instance_variable_get(:@logger)).to eq(Rails.logger)
    end
  end

  describe 'log methods' do
    before do
      CorrelationTracker.set(correlation_id: 'test-123', origin_type: 'test')
    end

    describe '#debug' do
      it 'logs message with correlation context' do
        expect(mock_logger).to receive(:debug) do |json|
          data = JSON.parse(json)
          expect(data['message']).to eq('Debug message')
          expect(data['correlation_id']).to eq('test-123')
          expect(data['origin_type']).to eq('test')
        end

        logger.debug('Debug message')
      end

      it 'accepts metadata' do
        expect(mock_logger).to receive(:debug) do |json|
          data = JSON.parse(json)
          expect(data['custom_field']).to eq('custom_value')
        end

        logger.debug('Message', custom_field: 'custom_value')
      end
    end

    describe '#info' do
      it 'logs message with correlation context' do
        expect(mock_logger).to receive(:info) do |json|
          data = JSON.parse(json)
          expect(data['message']).to eq('Info message')
          expect(data['correlation_id']).to eq('test-123')
        end

        logger.info('Info message')
      end
    end

    describe '#warn' do
      it 'logs message with correlation context' do
        expect(mock_logger).to receive(:warn) do |json|
          data = JSON.parse(json)
          expect(data['message']).to eq('Warning message')
          expect(data['correlation_id']).to eq('test-123')
        end

        logger.warn('Warning message')
      end
    end

    describe '#error' do
      it 'logs message with correlation context' do
        expect(mock_logger).to receive(:error) do |json|
          data = JSON.parse(json)
          expect(data['message']).to eq('Error message')
          expect(data['correlation_id']).to eq('test-123')
        end

        logger.error('Error message')
      end
    end

    describe '#fatal' do
      it 'logs message with correlation context' do
        expect(mock_logger).to receive(:fatal) do |json|
          data = JSON.parse(json)
          expect(data['message']).to eq('Fatal message')
          expect(data['correlation_id']).to eq('test-123')
        end

        logger.fatal('Fatal message')
      end
    end
  end

  describe 'hash-style logging' do
    it 'accepts hash as first argument' do
      expect(mock_logger).to receive(:info) do |json|
        data = JSON.parse(json)
        expect(data['event']).to eq('user_login')
        expect(data['user_id']).to eq(42)
      end

      logger.info(event: 'user_login', user_id: 42)
    end
  end

  describe 'correlation context merging' do
    it 'merges correlation context with metadata' do
      CorrelationTracker.set(
        correlation_id: 'test-123',
        user_id: 42,
        origin_type: 'test'
      )

      expect(mock_logger).to receive(:info) do |json|
        data = JSON.parse(json)
        expect(data['correlation_id']).to eq('test-123')
        expect(data['user_id']).to eq(42)
        expect(data['custom']).to eq('value')
      end

      logger.info('Message', custom: 'value')
    end

    it 'allows overriding correlation fields' do
      CorrelationTracker.set(correlation_id: 'test-123')

      expect(mock_logger).to receive(:info) do |json|
        data = JSON.parse(json)
        expect(data['correlation_id']).to eq('override-456')
      end

      logger.info('Message', correlation_id: 'override-456')
    end
  end

  describe 'when logger does not support level' do
    let(:limited_logger) { double('LimitedLogger') }
    let(:logger) { described_class.new(limited_logger) }

    it 'does not call unsupported methods' do
      allow(limited_logger).to receive(:respond_to?).with(:debug).and_return(false)

      expect(limited_logger).not_to receive(:debug)

      logger.debug('Message')
    end
  end
end
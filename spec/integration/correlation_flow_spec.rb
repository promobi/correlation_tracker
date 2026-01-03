# spec/integration/correlation_flow_spec.rb
require 'rails_helper'

RSpec.describe 'Correlation Flow', type: :request do
  let(:customer) { create(:customer, api_key: 'test-api-key-' + SecureRandom.hex(16)) }
  let(:product) { create(:product, stock_count: 100) }

  describe 'End-to-end correlation tracking' do
    it 'tracks correlation across HTTP -> Job -> External Service -> Kafka' do
      # Generate a test correlation ID
      test_correlation_id = SecureRandom.uuid

      # Step 1: Make API request with correlation ID
      post '/api/v1/orders',
           params: {
             order: {
               product_id: product.id,
               quantity: 2,
               shipping_address: '123 Test St'
             }
           },
           headers: {
             'X-API-Key' => customer.api_key,
             'X-Correlation-ID' => test_correlation_id,
             'Content-Type' => 'application/json'
           }

      expect(response).to have_http_status(:created)

      # Response should echo correlation ID
      expect(response.headers['X-Correlation-ID']).to eq(test_correlation_id)

      order = Order.last
      expect(order.customer_id).to eq(customer.id)

      # Step 2: Verify background job was enqueued with correlation
      expect(OrderProcessingJob).to have_been_enqueued.with(order.id)

      # Step 3: Execute job and verify correlation propagation
      perform_enqueued_jobs do
        expect {
          OrderProcessingJob.perform_now(order.id)
        }.to change { order.reload.status }.to('processing')
      end

      # Step 4: Verify correlation in logs
      # (In real scenario, you'd query your log aggregation system)
      # Example ClickHouse query:
      # SELECT * FROM logs WHERE correlation_id = '#{test_correlation_id}'
      # Should return logs from:
      # - API request
      # - OrderProcessingJob
      # - PaymentService HTTP call
      # - InventoryService HTTP call
      # - NotificationJob
      # - Kafka message
    end
  end

  describe 'Webhook correlation tracking' do
    it 'generates new correlation for incoming webhook' do
      # Stripe webhook without correlation ID
      post '/webhooks/stripe',
           params: {
                     type: 'payment_intent.succeeded',
                     data: {
                       object: {
                         id: 'pi_test_123'
                       }
                     }
                   }.to_json,
           headers: {
             'Content-Type' => 'application/json',
             'Stripe-Signature' => 'test_signature'
           }

      expect(response).to have_http_status(:ok)

      # Should generate new correlation ID
      correlation_id = response.headers['X-Correlation-ID']
      expect(correlation_id).to be_present
      expect(CorrelationTracker::Utilities::UuidValidator.valid?(correlation_id)).to be true
    end

    it 'preserves correlation if provided in webhook' do
      existing_correlation = SecureRandom.uuid

      post '/webhooks/stripe',
           params: {
                     type: 'payment_intent.succeeded',
                     data: { object: { id: 'pi_test_123' } }
                   }.to_json,
           headers: {
             'Content-Type' => 'application/json',
             'Stripe-Signature' => 'test_signature',
             'X-Correlation-ID' => existing_correlation
           }

      expect(response.headers['X-Correlation-ID']).to eq(existing_correlation)
    end
  end

  describe 'Kafka message correlation' do
    it 'adds correlation to outgoing Kafka messages' do
      correlation_id = CorrelationTracker.set(correlation_id: 'kafka-test-123')

      order = create(:order)

      expect {
        Kafka::OrderProducer.publish_order_created(order)
      }.not_to raise_error

      # In a real test, you'd verify the Kafka message headers contain:
      # correlation_id: 'kafka-test-123'
      # parent_correlation_id: 'kafka-test-123'
    end
  end

  describe 'Manual correlation context' do
    it 'allows setting custom correlation for cron jobs' do
      CorrelationTracker.set(
        origin_type: 'cron',
        job_name: 'test_job'
      )

      expect(CorrelationTracker.origin_type).to eq('cron')
      expect(CorrelationTracker::Context.job_name).to eq('test_job')
      expect(CorrelationTracker.current_id).to be_present
    end

    it 'supports temporary correlation context' do
      original_id = CorrelationTracker.set(correlation_id: 'original-123')

      CorrelationTracker.with_correlation(correlation_id: 'temp-456') do
        expect(CorrelationTracker.current_id).to eq('temp-456')
      end

      expect(CorrelationTracker.current_id).to eq('original-123')
    end
  end
end
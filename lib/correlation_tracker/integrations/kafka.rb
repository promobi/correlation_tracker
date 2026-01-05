# lib/correlation_tracker/integrations/kafka.rb
module CorrelationTracker
  module Integrations
    module Kafka
      # Producer middleware - adds correlation headers to messages
      class ProducerInterceptor
        def call(message)
          config = CorrelationTracker.configuration

          # Add correlation headers to Kafka message headers
          message.headers ||= {}

          if CorrelationTracker.current_id
            message.headers[config.kafka_header_key] = CorrelationTracker.current_id
            message.headers[config.kafka_parent_header_key] = CorrelationTracker.current_id
          end

          # Add additional metadata
          message.headers['origin_type'] = CorrelationTracker.origin_type if CorrelationTracker.origin_type
          message.headers['service_name'] = config.service_name

          yield(message)
        end
      end

      # Consumer middleware - extracts correlation from message headers
      class ConsumerInterceptor
        def call(message)
          config = CorrelationTracker.configuration

          # Extract correlation from Kafka headers
          headers = message.headers || {}

          correlation_id = headers[config.kafka_header_key] ||
                           headers['correlation_id'] ||
                           CorrelationTracker.generate_id

          parent_correlation_id = headers[config.kafka_parent_header_key] ||
                                  headers['parent_correlation_id']

          # Set correlation context
          CorrelationTracker.set(
            correlation_id: correlation_id,
            parent_correlation_id: parent_correlation_id,
            origin_type: 'kafka_consumer',
            kafka_topic: message.topic,
            kafka_partition: message.partition,
            kafka_offset: message.offset
          )

          log_message_consumption(message)

          begin
            yield
            log_message_processed(message)
          rescue => e
            log_message_error(message, e)
            raise
          end
        ensure
          CorrelationTracker.reset!
        end

        private

        def log_message_consumption(message)
          return unless logger

          logger.info(
            message: "Kafka message consumed",
            topic: message.topic,
            partition: message.partition,
            offset: message.offset,
            key: message.key,
            **CorrelationTracker.to_h
          )
        end

        def log_message_processed(message)
          return unless logger

          logger.info(
            message: "Kafka message processed",
            topic: message.topic,
            partition: message.partition,
            offset: message.offset,
            **CorrelationTracker.to_h
          )
        end

        def log_message_error(message, error)
          return unless logger

          logger.error(
            message: "Kafka message processing failed",
            topic: message.topic,
            partition: message.partition,
            offset: message.offset,
            error_class: error.class.name,
            error_message: error.message,
            backtrace: error.backtrace.first(10),
            **CorrelationTracker.to_h
          )
        end

        def logger
          defined?(Rails) ? Rails.logger : nil
        end
      end

      # Helper methods for manual Kafka operations
      module Helpers
        # Add correlation headers to a Kafka message
        def add_correlation_headers(headers = {})
          config = CorrelationTracker.configuration

          headers[config.kafka_header_key] = CorrelationTracker.current_id || CorrelationTracker.generate_id
          headers[config.kafka_parent_header_key] = CorrelationTracker.current_id if CorrelationTracker.current_id
          headers['origin_type'] = CorrelationTracker.origin_type if CorrelationTracker.origin_type
          headers['service_name'] = config.service_name

          headers
        end

        # Extract correlation from Kafka message headers
        def extract_correlation_from_headers(headers)
          config = CorrelationTracker.configuration

          {
            correlation_id: headers[config.kafka_header_key] || headers['correlation_id'],
            parent_correlation_id: headers[config.kafka_parent_header_key] || headers['parent_correlation_id']
          }
        end
      end
    end
  end
end

# Extend Kafka producer with correlation helpers
if defined?(::Kafka::Producer)
  ::Kafka::Producer.include(CorrelationTracker::Integrations::Kafka::Helpers)
end
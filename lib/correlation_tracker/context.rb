# lib/correlation_tracker/context.rb
module CorrelationTracker
  class Context < ActiveSupport::CurrentAttributes
    attribute :correlation_id
    attribute :parent_correlation_id
    attribute :origin_type
    attribute :user_id
    attribute :customer_id
    attribute :job_name
    attribute :webhook_source
    attribute :external_request_id
    attribute :email_type
    attribute :device_id
    attribute :task_type
    attribute :kafka_topic
    attribute :kafka_partition
    attribute :kafka_offset

    # Additional metadata storage
    attribute :metadata

    def metadata
      super || {}
    end

    # Helper to add custom metadata
    def self.add_metadata(key, value)
      current_metadata = metadata || {}
      current_metadata[key.to_sym] = value
      self.metadata = current_metadata
    end

    # Get all attributes as hash (excluding nil values)
    def self.attributes
      {
        correlation_id: correlation_id,
        parent_correlation_id: parent_correlation_id,
        origin_type: origin_type,
        user_id: user_id,
        customer_id: customer_id,
        job_name: job_name,
        webhook_source: webhook_source,
        external_request_id: external_request_id,
        email_type: email_type,
        device_id: device_id,
        task_type: task_type,
        kafka_topic: kafka_topic,
        kafka_partition: kafka_partition,
        kafka_offset: kafka_offset
      }.merge(metadata || {})
    end
  end
end
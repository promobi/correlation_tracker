# lib/correlation_tracker/utilities/uuid_validator.rb
module CorrelationTracker
  module Utilities
    class UuidValidator
      UUID_V4_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i
      UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

      def self.valid?(value, strict: false)
        return false if value.nil? || value.empty?

        pattern = strict ? UUID_V4_PATTERN : UUID_PATTERN
        value.match?(pattern)
      end

      def self.valid_v4?(value)
        valid?(value, strict: true)
      end
    end
  end
end
# lib/correlation_tracker/utilities/uuid_validator.rb
module CorrelationTracker
  module Utilities
    # UUID validation and manipulation utility
    #
    # Provides methods to validate UUIDs (v1, v4, v5, v7), extract timestamps from
    # time-ordered UUIDs (v7), generate UUIDs, and compare UUIDs.
    #
    # Supports strict validation (only v4/v7) and version-specific validation.
    #
    # @example Basic validation
    #   UuidValidator.valid?('550e8400-e29b-41d4-a716-446655440000')
    #   # => true
    #
    # @example Extract timestamp from UUID v7
    #   timestamp = UuidValidator.extract_timestamp(uuid_v7)
    #   # => 2024-03-15 10:30:45 UTC
    #
    # @example Generate UUID
    #   UuidValidator.generate(7)  # Generate UUID v7
    #   # => "018e8c3a-4e4a-7b3c-9a1f-123456789abc"
    class UuidValidator
      # UUID format: 8-4-4-4-12 hexadecimal characters
      UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i.freeze

      # UUID v4 format (version 4 - random)
      # Format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
      # where y is one of [8, 9, a, b]
      UUID_V4_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i.freeze

      # UUID v7 format (version 7 - time-ordered)
      # Format: xxxxxxxx-xxxx-7xxx-yxxx-xxxxxxxxxxxx
      # where y is one of [8, 9, a, b]
      UUID_V7_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i.freeze

      class << self
        # Validates if a string is a valid UUID
        #
        # @param value [String] the string to validate
        # @param strict [Boolean] if true, only accepts UUID v4 or v7
        # @param version [Integer, nil] if provided, validates specific version (4 or 7)
        # @return [Boolean] true if valid UUID
        #
        # @example Basic validation
        #   UuidValidator.valid?('550e8400-e29b-41d4-a716-446655440000')
        #   # => true
        #
        # @example Strict validation (only v4 and v7)
        #   UuidValidator.valid?('550e8400-e29b-41d4-a716-446655440000', strict: true)
        #   # => true (if v4 or v7)
        #
        # @example Version-specific validation
        #   UuidValidator.valid?(uuid, version: 7)
        #   # => true only if UUID v7
        def valid?(value, strict: false, version: nil)
          return false if value.nil? || !value.is_a?(String)
          return false unless CorrelationTracker.configuration.validate_uuid_format

          # If version specified, validate that specific version
          return valid_version?(value, version) if version

          # If strict mode, only accept v4 or v7
          return (valid_v4?(value) || valid_v7?(value)) if strict

          # Otherwise, accept any valid UUID format
          value.match?(UUID_REGEX)
        end

        # Validates if a string is a valid UUID v4
        #
        # @param value [String] the string to validate
        # @return [Boolean] true if valid UUID v4
        #
        # @example
        #   UuidValidator.valid_v4?('550e8400-e29b-41d4-a716-446655440000')
        #   # => true (if version nibble is 4)
        def valid_v4?(value)
          return false if value.nil? || !value.is_a?(String)

          value.match?(UUID_V4_REGEX)
        end

        # Validates if a string is a valid UUID v7
        #
        # @param value [String] the string to validate
        # @return [Boolean] true if valid UUID v7
        #
        # @example
        #   UuidValidator.valid_v7?('018e8c3a-4e4a-7b3c-9a1f-123456789abc')
        #   # => true (if version nibble is 7)
        def valid_v7?(value)
          return false if value.nil? || !value.is_a?(String)

          value.match?(UUID_V7_REGEX)
        end

        # Detects the version of a UUID
        #
        # @param value [String] the UUID string
        # @return [Integer, nil] the version number (1-8) or nil if invalid
        #
        # @example
        #   UuidValidator.version('550e8400-e29b-41d4-a716-446655440000')
        #   # => 4
        #
        #   UuidValidator.version('018e8c3a-4e4a-7b3c-9a1f-123456789abc')
        #   # => 7
        def version(value)
          return nil unless value.is_a?(String) && value.match?(UUID_REGEX)

          # Extract version from 13th character (after removing hyphens)
          # UUID format: xxxxxxxx-xxxx-Mxxx-Nxxx-xxxxxxxxxxxx
          # where M is the version
          version_char = value[14] # Position 14 in hyphenated format
          version_char.to_i(16) >> 0 # Convert hex to integer
        rescue
          nil
        end

        # Checks if UUID is time-ordered (v1, v6, or v7)
        #
        # @param value [String] the UUID string
        # @return [Boolean] true if UUID contains timestamp
        #
        # @example
        #   UuidValidator.time_ordered?('018e8c3a-4e4a-7b3c-9a1f-123456789abc')
        #   # => true (UUID v7 is time-ordered)
        def time_ordered?(value)
          v = version(value)
          [1, 6, 7].include?(v)
        end

        # Extracts timestamp from UUID v7
        #
        # @param value [String] the UUID v7 string
        # @return [Time, nil] the timestamp or nil if not v7
        #
        # @example
        #   UuidValidator.extract_timestamp('018e8c3a-4e4a-7b3c-9a1f-123456789abc')
        #   # => 2024-03-15 10:30:45 UTC
        def extract_timestamp(value)
          return nil unless valid_v7?(value)

          # UUID v7 format: unix_ts_ms (48 bits) + ver (4) + rand_a (12) + var (2) + rand_b (62)
          # First 48 bits = milliseconds since Unix epoch

          # Remove hyphens and get first 12 hex characters (48 bits)
          hex_timestamp = value.gsub('-', '')[0...12]

          # Convert to milliseconds
          milliseconds = hex_timestamp.to_i(16)

          # Convert to Time object
          Time.at(milliseconds / 1000.0).utc
        rescue
          nil
        end

        # Validates a specific UUID version
        #
        # @param value [String] the UUID string
        # @param version_number [Integer] the version to validate (1-8)
        # @return [Boolean] true if matches specified version
        def valid_version?(value, version_number)
          return false unless [1, 2, 3, 4, 5, 6, 7, 8].include?(version_number)

          version(value) == version_number
        end

        # Compares two UUIDs (useful for v7 time ordering)
        #
        # @param uuid1 [String] first UUID
        # @param uuid2 [String] second UUID
        # @return [Integer] -1 if uuid1 < uuid2, 0 if equal, 1 if uuid1 > uuid2, nil if invalid
        #
        # @example
        #   UuidValidator.compare(earlier_uuid, later_uuid)
        #   # => -1
        def compare(uuid1, uuid2)
          return nil unless valid?(uuid1) && valid?(uuid2)

          # For v7 UUIDs, compare timestamps
          if valid_v7?(uuid1) && valid_v7?(uuid2)
            ts1 = extract_timestamp(uuid1)
            ts2 = extract_timestamp(uuid2)
            return ts1 <=> ts2 if ts1 && ts2
          end

          # Otherwise, lexicographic comparison
          uuid1 <=> uuid2
        end

        # Generates a sample UUID of specified version (for testing)
        #
        # @param version [Integer] version to generate (4 or 7)
        # @return [String] a valid UUID
        #
        # @example
        #   UuidValidator.generate(4)
        #   # => "550e8400-e29b-41d4-a716-446655440000"
        #
        #   UuidValidator.generate(7)
        #   # => "018e8c3a-4e4a-7b3c-9a1f-123456789abc"
        def generate(version = 4)
          case version
          when 4
            SecureRandom.uuid
          when 7
            # Check if Ruby version supports uuid_v7
            if SecureRandom.respond_to?(:uuid_v7)
              SecureRandom.uuid_v7
            else
              # Fallback: generate manually
              generate_uuid_v7
            end
          else
            raise ArgumentError, "Unsupported UUID version: #{version}"
          end
        end

        private

        # Manual UUID v7 generation for Ruby < 3.3
        def generate_uuid_v7
          # Get current timestamp in milliseconds
          timestamp_ms = (Time.now.to_f * 1000).to_i

          # Convert to 48-bit hex (12 hex chars)
          timestamp_hex = format('%012x', timestamp_ms & 0xFFFFFFFFFFFF)

          # Generate random bits
          # 12 bits for rand_a (after version)
          rand_a = SecureRandom.random_number(0x1000)

          # 62 bits for rand_b (after variant)
          rand_b = SecureRandom.random_number(0x3FFFFFFFFFFFFFFF)

          # Construct UUID v7
          # Format: tttttttt-tttt-7xxx-yxxx-xxxxxxxxxxxx
          format(
            '%s-%s-7%03x-%04x-%012x',
            timestamp_hex[0...8],
            timestamp_hex[8...12],
            rand_a,
            0x8000 | (rand_b >> 48), # Set variant bits (10xx)
            rand_b & 0xFFFFFFFFFFFF
          )
        end
      end
    end
  end
end
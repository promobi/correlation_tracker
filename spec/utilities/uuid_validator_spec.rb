# spec/utilities/uuid_validator_spec.rb
require 'spec_helper'
require 'benchmark'

RSpec.describe CorrelationTracker::Utilities::UuidValidator do
  describe '.valid?' do
    context 'with valid UUIDs' do
      it 'accepts UUID v1' do
        uuid = '6ba7b810-9dad-11d1-80b4-00c04fd430c8'
        expect(described_class.valid?(uuid)).to be true
      end

      it 'accepts UUID v4' do
        uuid = '550e8400-e29b-41d4-a716-446655440000'
        expect(described_class.valid?(uuid)).to be true
      end

      it 'accepts UUID v7' do
        uuid = '018e8c3a-4e4a-7b3c-9a1f-123456789abc'
        expect(described_class.valid?(uuid)).to be true
      end

      it 'accepts lowercase UUIDs' do
        uuid = 'f47ac10b-58cc-4372-a567-0e02b2c3d479'
        expect(described_class.valid?(uuid)).to be true
      end

      it 'accepts uppercase UUIDs' do
        uuid = 'F47AC10B-58CC-4372-A567-0E02B2C3D479'
        expect(described_class.valid?(uuid)).to be true
      end

      it 'accepts mixed case UUIDs' do
        uuid = 'F47ac10b-58CC-4372-a567-0E02b2c3D479'
        expect(described_class.valid?(uuid)).to be true
      end
    end

    context 'with invalid UUIDs' do
      it 'rejects nil' do
        expect(described_class.valid?(nil)).to be false
      end

      it 'rejects empty string' do
        expect(described_class.valid?('')).to be false
      end

      it 'rejects non-UUID strings' do
        expect(described_class.valid?('not-a-uuid')).to be false
      end

      it 'rejects UUIDs without hyphens' do
        uuid = '550e8400e29b41d4a716446655440000'
        expect(described_class.valid?(uuid)).to be false
      end

      it 'rejects UUIDs with wrong structure' do
        uuid = '550e8400-e29b-41d4-a716'
        expect(described_class.valid?(uuid)).to be false
      end

      it 'rejects UUIDs with extra characters' do
        uuid = '550e8400-e29b-41d4-a716-446655440000-extra'
        expect(described_class.valid?(uuid)).to be false
      end

      it 'rejects UUIDs with invalid characters' do
        uuid = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
        expect(described_class.valid?(uuid)).to be false
      end

      it 'rejects Stripe IDs' do
        expect(described_class.valid?('req_abc123xyz')).to be false
        expect(described_class.valid?('ch_1MqHY82eZvKYlo2C')).to be false
      end

      it 'rejects integers' do
        expect(described_class.valid?(12345)).to be false
      end

      it 'rejects arrays' do
        expect(described_class.valid?([])).to be false
      end
    end

    context 'with strict validation' do
      it 'accepts UUID v4' do
        uuid = '550e8400-e29b-41d4-a716-446655440000'
        expect(described_class.valid?(uuid, strict: true)).to be true
      end

      it 'accepts UUID v7' do
        uuid = '018e8c3a-4e4a-7b3c-9a1f-123456789abc'
        expect(described_class.valid?(uuid, strict: true)).to be true
      end

      it 'rejects UUID v1' do
        uuid = '6ba7b810-9dad-11d1-80b4-00c04fd430c8'
        expect(described_class.valid?(uuid, strict: true)).to be false
      end

      it 'rejects UUID v5' do
        uuid = 'a6edc906-2f9f-5fb2-a373-efac406f0ef2'
        expect(described_class.valid?(uuid, strict: true)).to be false
      end
    end

    context 'with version-specific validation' do
      it 'validates UUID v4 when version: 4 specified' do
        uuid_v4 = '550e8400-e29b-41d4-a716-446655440000'
        uuid_v7 = '018e8c3a-4e4a-7b3c-9a1f-123456789abc'

        expect(described_class.valid?(uuid_v4, version: 4)).to be true
        expect(described_class.valid?(uuid_v7, version: 4)).to be false
      end

      it 'validates UUID v7 when version: 7 specified' do
        uuid_v4 = '550e8400-e29b-41d4-a716-446655440000'
        uuid_v7 = '018e8c3a-4e4a-7b3c-9a1f-123456789abc'

        expect(described_class.valid?(uuid_v7, version: 7)).to be true
        expect(described_class.valid?(uuid_v4, version: 7)).to be false
      end
    end
  end

  describe '.valid_v4?' do
    it 'accepts UUID v4' do
      uuid = '550e8400-e29b-41d4-a716-446655440000'
      expect(described_class.valid_v4?(uuid)).to be true
    end

    it 'rejects UUID v1' do
      uuid = '6ba7b810-9dad-11d1-80b4-00c04fd430c8'
      expect(described_class.valid_v4?(uuid)).to be false
    end

    it 'rejects UUID v7' do
      uuid = '018e8c3a-4e4a-7b3c-9a1f-123456789abc'
      expect(described_class.valid_v4?(uuid)).to be false
    end

    it 'rejects nil' do
      expect(described_class.valid_v4?(nil)).to be false
    end

    it 'rejects non-string values' do
      expect(described_class.valid_v4?(12345)).to be false
    end

    it 'validates version nibble is 4' do
      # Version nibble is at position 14 (0-indexed)
      uuid_wrong_version = '550e8400-e29b-51d4-a716-446655440000' # Version 5
      expect(described_class.valid_v4?(uuid_wrong_version)).to be false
    end

    it 'validates variant bits are correct' do
      # Variant bits should be 10xx (8, 9, a, or b)
      uuid_wrong_variant = '550e8400-e29b-41d4-f716-446655440000' # Variant f
      expect(described_class.valid_v4?(uuid_wrong_variant)).to be false
    end
  end

  describe '.valid_v7?' do
    it 'accepts UUID v7' do
      uuid = '018e8c3a-4e4a-7b3c-9a1f-123456789abc'
      expect(described_class.valid_v7?(uuid)).to be true
    end

    it 'accepts generated UUID v7' do
      skip 'Ruby < 3.3' unless SecureRandom.respond_to?(:uuid_v7)

      uuid = SecureRandom.uuid_v7
      expect(described_class.valid_v7?(uuid)).to be true
    end

    it 'rejects UUID v4' do
      uuid = '550e8400-e29b-41d4-a716-446655440000'
      expect(described_class.valid_v7?(uuid)).to be false
    end

    it 'rejects UUID v1' do
      uuid = '6ba7b810-9dad-11d1-80b4-00c04fd430c8'
      expect(described_class.valid_v7?(uuid)).to be false
    end

    it 'rejects nil' do
      expect(described_class.valid_v7?(nil)).to be false
    end

    it 'validates version nibble is 7' do
      uuid_wrong_version = '018e8c3a-4e4a-4b3c-9a1f-123456789abc' # Version 4
      expect(described_class.valid_v7?(uuid_wrong_version)).to be false
    end

    it 'validates variant bits are correct' do
      uuid_wrong_variant = '018e8c3a-4e4a-7b3c-fa1f-123456789abc' # Variant f
      expect(described_class.valid_v7?(uuid_wrong_variant)).to be false
    end
  end

  describe '.version' do
    it 'detects UUID v1' do
      uuid = '6ba7b810-9dad-11d1-80b4-00c04fd430c8'
      expect(described_class.version(uuid)).to eq(1)
    end

    it 'detects UUID v4' do
      uuid = '550e8400-e29b-41d4-a716-446655440000'
      expect(described_class.version(uuid)).to eq(4)
    end

    it 'detects UUID v7' do
      uuid = '018e8c3a-4e4a-7b3c-9a1f-123456789abc'
      expect(described_class.version(uuid)).to eq(7)
    end

    it 'detects UUID v5' do
      uuid = 'a6edc906-2f9f-5fb2-a373-efac406f0ef2'
      expect(described_class.version(uuid)).to eq(5)
    end

    it 'returns nil for invalid UUID' do
      expect(described_class.version('invalid')).to be_nil
    end

    it 'returns nil for nil' do
      expect(described_class.version(nil)).to be_nil
    end

    it 'returns nil for non-string' do
      expect(described_class.version(12345)).to be_nil
    end
  end

  describe '.time_ordered?' do
    it 'returns true for UUID v1' do
      uuid = '6ba7b810-9dad-11d1-80b4-00c04fd430c8'
      expect(described_class.time_ordered?(uuid)).to be true
    end

    it 'returns true for UUID v7' do
      uuid = '018e8c3a-4e4a-7b3c-9a1f-123456789abc'
      expect(described_class.time_ordered?(uuid)).to be true
    end

    it 'returns false for UUID v4' do
      uuid = '550e8400-e29b-41d4-a716-446655440000'
      expect(described_class.time_ordered?(uuid)).to be false
    end

    it 'returns false for invalid UUID' do
      expect(described_class.time_ordered?('invalid')).to be false
    end
  end

  describe '.extract_timestamp' do
    it 'extracts timestamp from UUID v7' do
      # UUID v7 with known timestamp
      # First 48 bits represent milliseconds since Unix epoch

      # Create a UUID v7 with a specific timestamp (2024-03-15 10:30:45.123 UTC)
      time = Time.utc(2024, 3, 15, 10, 30, 45, 123000)
      timestamp_ms = (time.to_f * 1000).to_i

      # Manually construct UUID v7
      timestamp_hex = format('%012x', timestamp_ms)
      uuid = "#{timestamp_hex[0...8]}-#{timestamp_hex[8...12]}-7abc-9def-123456789abc"

      extracted = described_class.extract_timestamp(uuid)

      expect(extracted).to be_a(Time)
      expect(extracted.to_i).to eq(time.to_i)
    end

    it 'extracts timestamp from generated UUID v7' do
      skip 'Ruby < 3.3' unless SecureRandom.respond_to?(:uuid_v7)

      before_time = Time.now.utc - 0.001 # 1ms buffer for precision
      uuid = SecureRandom.uuid_v7
      after_time = Time.now.utc + 0.001 # 1ms buffer for precision

      extracted = described_class.extract_timestamp(uuid)

      expect(extracted).to be_between(before_time, after_time)
      expect(extracted).to be_a(Time)
    end

    it 'returns nil for UUID v4' do
      uuid = '550e8400-e29b-41d4-a716-446655440000'
      expect(described_class.extract_timestamp(uuid)).to be_nil
    end

    it 'returns nil for invalid UUID' do
      expect(described_class.extract_timestamp('invalid')).to be_nil
    end

    it 'returns nil for nil' do
      expect(described_class.extract_timestamp(nil)).to be_nil
    end
  end

  describe '.valid_version?' do
    it 'validates specific version' do
      uuid_v4 = '550e8400-e29b-41d4-a716-446655440000'
      uuid_v7 = '018e8c3a-4e4a-7b3c-9a1f-123456789abc'

      expect(described_class.valid_version?(uuid_v4, 4)).to be true
      expect(described_class.valid_version?(uuid_v4, 7)).to be false
      expect(described_class.valid_version?(uuid_v7, 7)).to be true
      expect(described_class.valid_version?(uuid_v7, 4)).to be false
    end

    it 'rejects invalid version numbers' do
      uuid = '550e8400-e29b-41d4-a716-446655440000'

      expect(described_class.valid_version?(uuid, 0)).to be false
      expect(described_class.valid_version?(uuid, 9)).to be false
      expect(described_class.valid_version?(uuid, 99)).to be false
    end
  end

  describe '.compare' do
    context 'with UUID v7' do
      it 'compares based on timestamps' do
        # Earlier timestamp
        earlier = '018e8c3a-4e4a-7b3c-9a1f-123456789abc'
        # Later timestamp (higher first 48 bits)
        later = '018e8c3a-4e4b-7b3c-9a1f-123456789abc'

        expect(described_class.compare(earlier, later)).to eq(-1)
        expect(described_class.compare(later, earlier)).to eq(1)
        expect(described_class.compare(earlier, earlier)).to eq(0)
      end

      it 'uses generated UUIDs for comparison' do
        skip 'Ruby < 3.3' unless SecureRandom.respond_to?(:uuid_v7)

        uuid1 = SecureRandom.uuid_v7
        sleep 0.001 # Ensure different timestamp
        uuid2 = SecureRandom.uuid_v7

        expect(described_class.compare(uuid1, uuid2)).to eq(-1)
      end
    end

    context 'with UUID v4' do
      it 'compares lexicographically' do
        uuid1 = '550e8400-e29b-41d4-a716-446655440000'
        uuid2 = '550e8400-e29b-41d4-a716-446655440001'

        expect(described_class.compare(uuid1, uuid2)).to eq(-1)
      end
    end

    context 'with mixed versions' do
      it 'compares lexicographically' do
        uuid_v4 = '550e8400-e29b-41d4-a716-446655440000'
        uuid_v7 = '018e8c3a-4e4a-7b3c-9a1f-123456789abc'

        result = described_class.compare(uuid_v4, uuid_v7)
        expect(result).to be_a(Integer)
      end
    end

    it 'returns nil for invalid UUIDs' do
      expect(described_class.compare('invalid', 'also-invalid')).to be_nil
      expect(described_class.compare('550e8400-e29b-41d4-a716-446655440000', 'invalid')).to be_nil
    end
  end

  describe '.generate' do
    context 'UUID v4' do
      it 'generates valid UUID v4' do
        uuid = described_class.generate(4)

        expect(described_class.valid_v4?(uuid)).to be true
      end

      it 'generates default UUID v4' do
        uuid = described_class.generate

        expect(described_class.valid_v4?(uuid)).to be true
      end

      it 'generates unique UUIDs' do
        uuids = 100.times.map { described_class.generate(4) }

        expect(uuids.uniq.size).to eq(100)
      end
    end

    context 'UUID v7' do
      it 'generates valid UUID v7' do
        uuid = described_class.generate(7)

        expect(described_class.valid_v7?(uuid)).to be true
      end

      it 'generates time-ordered UUIDs' do
        uuid1 = described_class.generate(7)
        sleep 0.001
        uuid2 = described_class.generate(7)

        expect(described_class.compare(uuid1, uuid2)).to eq(-1)
      end

      it 'extracts valid timestamp' do
        before_time = Time.now.utc
        uuid = described_class.generate(7)
        after_time = Time.now.utc

        timestamp = described_class.extract_timestamp(uuid)

        expect(timestamp).to be_between(before_time - 1, after_time + 1)
      end

      it 'generates unique UUIDs' do
        uuids = 100.times.map { described_class.generate(7) }

        expect(uuids.uniq.size).to eq(100)
      end
    end

    it 'raises error for unsupported version' do
      expect {
        described_class.generate(99)
      }.to raise_error(ArgumentError, /Unsupported UUID version/)
    end
  end

  describe 'performance' do
    it 'validates UUID v4 quickly' do
      uuid = SecureRandom.uuid

      time = Benchmark.realtime do
        10_000.times { described_class.valid_v4?(uuid) }
      end

      expect(time).to be < 1.0
    end

    it 'validates UUID v7 quickly' do
      uuid = described_class.generate(7)

      time = Benchmark.realtime do
        10_000.times { described_class.valid_v7?(uuid) }
      end

      expect(time).to be < 1.0
    end

    it 'detects version quickly' do
      uuid = SecureRandom.uuid

      time = Benchmark.realtime do
        10_000.times { described_class.version(uuid) }
      end

      expect(time).to be < 1.0
    end

    it 'generates UUID v7 quickly' do
      time = Benchmark.realtime do
        1_000.times { described_class.generate(7) }
      end

      expect(time).to be < 1.0
    end
  end

  describe 'edge cases' do
    it 'handles uppercase and lowercase consistently' do
      uuid_lower = '018e8c3a-4e4a-7b3c-9a1f-123456789abc'
      uuid_upper = '018E8C3A-4E4A-7B3C-9A1F-123456789ABC'

      expect(described_class.valid_v7?(uuid_lower)).to be true
      expect(described_class.valid_v7?(uuid_upper)).to be true
      expect(described_class.version(uuid_lower)).to eq(7)
      expect(described_class.version(uuid_upper)).to eq(7)
    end

    it 'handles boundary timestamps in UUID v7' do
      # Test with timestamp at Unix epoch
      # UUID v7 format: xxxxxxxx-xxxx-7xxx-yxxx-xxxxxxxxxxxx
      # First 48 bits (12 hex chars) = timestamp in milliseconds
      uuid_epoch = '00000000-0000-7abc-9def-123456789abc'
      timestamp = described_class.extract_timestamp(uuid_epoch)

      expect(timestamp).to be_a(Time)
      expect(timestamp.to_i).to eq(0)
    end

    it 'handles very large timestamps in UUID v7' do
      # Test with maximum 48-bit timestamp (year 10889)
      max_timestamp_hex = 'ffffffffffff'
      uuid = "#{max_timestamp_hex[0...8]}-#{max_timestamp_hex[8...12]}-7abc-9def-123456789abc"

      timestamp = described_class.extract_timestamp(uuid)

      expect(timestamp).to be_a(Time)
      expect(timestamp.year).to be > 2200
    end
  end

  describe 'real-world scenarios' do
    it 'validates correlation IDs from CorrelationTracker' do
      id1 = CorrelationTracker.set(correlation_id: described_class.generate(4))
      id2 = CorrelationTracker.set(correlation_id: described_class.generate(7))

      expect(described_class.valid?(id1)).to be true
      expect(described_class.valid?(id2)).to be true
    end

    it 'sorts UUID v7 chronologically' do
      uuids = []

      5.times do
        uuids << described_class.generate(7)
        sleep 0.002
      end

      sorted = uuids.sort { |a, b| described_class.compare(a, b) }

      expect(sorted).to eq(uuids)
    end

    it 'identifies UUID version from logs' do
      test_uuids = {
        '6ba7b810-9dad-11d1-80b4-00c04fd430c8' => 1,
        '550e8400-e29b-41d4-a716-446655440000' => 4,
        'a6edc906-2f9f-5fb2-a373-efac406f0ef2' => 5,
        '018e8c3a-4e4a-7b3c-9a1f-123456789abc' => 7
      }

      test_uuids.each do |uuid, expected_version|
        expect(described_class.version(uuid)).to eq(expected_version)
      end
    end
  end
end
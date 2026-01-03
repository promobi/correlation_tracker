# spec/utilities/uuid_validator_spec.rb
require 'spec_helper'

RSpec.describe CorrelationTracker::Utilities::UuidValidator do
  describe '.valid?' do
    it 'validates correct UUIDs' do
      valid_uuids = [
        '550e8400-e29b-41d4-a716-446655440000',
        '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
        'f47ac10b-58cc-4372-a567-0e02b2c3d479'
      ]

      valid_uuids.each do |uuid|
        expect(described_class.valid?(uuid)).to be true
      end
    end

    it 'rejects invalid UUIDs' do
      invalid_uuids = [
        nil,
        '',
        'not-a-uuid',
        '550e8400-e29b-41d4-a716',  # too short
        '550e8400-e29b-41d4-a716-446655440000-extra',  # too long
        'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'  # invalid characters
      ]

      invalid_uuids.each do |uuid|
        expect(described_class.valid?(uuid)).to be false
      end
    end

    context 'with strict validation' do
      it 'validates UUID v4' do
        uuid_v4 = '550e8400-e29b-41d4-a716-446655440000'
        expect(described_class.valid?(uuid_v4, strict: true)).to be true
      end

      it 'rejects non-v4 UUIDs' do
        uuid_v1 = '6ba7b810-9dad-11d1-80b4-00c04fd430c8'
        expect(described_class.valid?(uuid_v1, strict: true)).to be false
      end
    end
  end
end
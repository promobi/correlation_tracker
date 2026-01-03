# spec/support/shared_examples.rb
RSpec.shared_examples 'a UUID validator' do
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
      '550e8400-e29b-41d4-a716',
      '550e8400-e29b-41d4-a716-446655440000-extra',
      'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    ]

    invalid_uuids.each do |uuid|
      expect(described_class.valid?(uuid)).to be false
    end
  end
end

RSpec.shared_examples 'an extractor' do
  it 'responds to extract method' do
    expect(subject).to respond_to(:extract)
  end

  it 'returns a hash with correlation data' do
    result = subject.extract(request)
    expect(result).to be_a(Hash)
    expect(result).to have_key(:correlation_id)
  end
end

RSpec.shared_examples 'correlation ID propagation' do
  it 'propagates correlation ID to downstream calls' do
    CorrelationTracker.set(correlation_id: 'test-123')

    # Expectation defined in specific spec
    expect(propagated_correlation_id).to eq('test-123')
  end
end
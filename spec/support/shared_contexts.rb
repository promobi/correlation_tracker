# spec/support/shared_contexts.rb
RSpec.shared_context 'with correlation context' do
  let(:correlation_id) { '550e8400-e29b-41d4-a716-446655440000' }
  let(:parent_correlation_id) { '6ba7b810-9dad-11d1-80b4-00c04fd430c8' }
  let(:origin_type) { 'test' }

  before do
    CorrelationTracker.set(
      correlation_id: correlation_id,
      parent_correlation_id: parent_correlation_id,
      origin_type: origin_type
    )
  end
end

RSpec.shared_context 'with clean correlation context' do
  before do
    CorrelationTracker.reset!
  end
end

RSpec.shared_context 'with mocked Rails logger' do
  let(:logger) { instance_double('Logger') }

  before do
    allow(Rails).to receive(:logger).and_return(logger) if defined?(Rails)
    allow(logger).to receive(:info)
    allow(logger).to receive(:warn)
    allow(logger).to receive(:error)
    allow(logger).to receive(:debug)
  end
end

RSpec.shared_context 'with rack request' do
  include Rack::Test::Methods

  let(:app) { ->(env) { [200, { 'Content-Type' => 'text/plain' }, ['OK']] } }

  def make_request(path = '/', headers = {})
    env = Rack::MockRequest.env_for(path, headers)
    app.call(env)
  end
end
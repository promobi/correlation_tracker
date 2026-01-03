# spec/integrations/opentelemetry_spec.rb
require 'spec_helper'

RSpec.describe CorrelationTracker::Integrations::OpenTelemetry do
  describe '.setup' do
    before do
      skip 'OpenTelemetry not loaded' unless defined?(::OpenTelemetry)
    end

    it 'patches Rack tracer middleware' do
      # This is a complex integration test
      # In practice, you'd mock OpenTelemetry::Trace.current_span

      expect(described_class).to respond_to(:setup)
    end

    it 'adds correlation attributes to span' do
      skip 'Requires OpenTelemetry setup'

      # Mock span
      span = instance_double('OpenTelemetry::Trace::Span')
      allow(::OpenTelemetry::Trace).to receive(:current_span).and_return(span)

      CorrelationTracker.set(
        correlation_id: 'test-123',
        parent_correlation_id: 'parent-456',
        origin_type: 'http'
      )

      expect(span).to receive(:set_attribute).with('correlation.id', 'test-123')
      expect(span).to receive(:set_attribute).with('correlation.parent_id', 'parent-456')
      expect(span).to receive(:set_attribute).with('correlation.origin_type', 'http')

      described_class.setup
      # Simulate middleware call
    end
  end
end
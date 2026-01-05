# spec/integrations/action_controller_spec.rb
require 'spec_helper'
require 'action_controller'
require 'correlation_tracker/integrations/action_controller'

# Define a minimal Rails stub for testing
unless defined?(Rails)
  module Rails
    def self.logger
      @logger ||= Logger.new(nil)
    end

    def self.logger=(logger)
      @logger = logger
    end
  end
end

RSpec.describe CorrelationTracker::Integrations::ActionController do
  # Mock controller for testing
  class TestController < ActionController::Base
    include CorrelationTracker::Integrations::ActionController

    def index
      render plain: 'OK'
    end

    def current_user
      OpenStruct.new(id: 42)
    end
  end

  let(:controller) { TestController.new }
  let(:request) { instance_double('ActionDispatch::Request') }
  let(:response) { instance_double('ActionDispatch::Response') }

  before do
    allow(controller).to receive(:request).and_return(request)
    allow(controller).to receive(:response).and_return(response)
    allow(controller).to receive(:params).and_return({})
    allow(response).to receive(:status).and_return(200)
  end

  describe 'included hooks' do
    it 'adds before_action callback' do
      callbacks = TestController._process_action_callbacks.select do |callback|
        callback.filter == :set_correlation_user_context
      end

      expect(callbacks).not_to be_empty
    end
  end

  describe '#set_correlation_user_context' do
    it 'sets user_id from current_user' do
      CorrelationTracker.set(correlation_id: 'test-123')

      controller.send(:set_correlation_user_context)

      expect(CorrelationTracker::Context.user_id).to eq(42)
    end

    it 'does not set user_id if current_user not available' do
      controller_without_user = Class.new(ActionController::Base) do
        include CorrelationTracker::Integrations::ActionController
      end.new

      allow(controller_without_user).to receive(:request).and_return(request)

      controller_without_user.send(:set_correlation_user_context)

      expect(CorrelationTracker::Context.user_id).to be_nil
    end

    it 'does not set user_id if current_user is nil' do
      allow(controller).to receive(:current_user).and_return(nil)

      controller.send(:set_correlation_user_context)

      expect(CorrelationTracker::Context.user_id).to be_nil
    end
  end

  describe '#append_info_to_payload' do
    it 'merges correlation context into payload' do
      CorrelationTracker.set(
        correlation_id: 'test-123',
        origin_type: 'http',
        user_id: 42
      )

      payload = {}
      controller.send(:append_info_to_payload, payload)

      expect(payload[:correlation_id]).to eq('test-123')
      expect(payload[:origin_type]).to eq('http')
      expect(payload[:user_id]).to eq(42)
    end

    it 'handles empty correlation context' do
      payload = {}
      controller.send(:append_info_to_payload, payload)

      expect(payload).to be_a(Hash)
    end
  end

  # Error handling is typically done at the Rails application level
  # via exception tracking services or custom error handlers
end
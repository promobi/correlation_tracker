# lib/correlation_tracker/integrations/action_controller.rb
module CorrelationTracker
  module Integrations
    # ActionController integration for automatic user context tracking
    #
    # This module is automatically included in all ActionController::Base controllers
    # when CorrelationTracker is loaded in a Rails application.
    #
    # It provides:
    # - Automatic user_id tracking from current_user (if available)
    # - Correlation context inclusion in request payload for logging
    #
    # @example Manual inclusion (if auto-include is disabled)
    #   class ApplicationController < ActionController::Base
    #     include CorrelationTracker::Integrations::ActionController
    #   end
    #
    # @example Access user_id in logs
    #   # In a controller action with authenticated user
    #   CorrelationTracker.to_h
    #   # => { correlation_id: "...", user_id: 123, ... }
    module ActionController
      extend ActiveSupport::Concern

      included do
        before_action :set_correlation_user_context
      end

      private

      # Sets the user context from current_user if available
      #
      # This method is automatically called as a before_action on every request.
      # It checks if the controller responds to current_user and sets the user_id
      # in the correlation context.
      #
      # @return [void]
      # @api private
      def set_correlation_user_context
        # Set user context if available
        if respond_to?(:current_user, true) && current_user
          CorrelationTracker::Context.user_id = current_user.id
        end
      end

      # Appends correlation context to the Rails instrumentation payload
      #
      # This method merges the correlation context into the payload that's sent
      # to Rails instrumentation subscribers (e.g., Lograge).
      #
      # @param payload [Hash] the instrumentation payload
      # @return [void]
      # @api private
      def append_info_to_payload(payload)
        super
        payload.merge!(CorrelationTracker.to_h)
      end
    end
  end
end

# Auto-include in all controllers
ActiveSupport.on_load(:action_controller) do
  include CorrelationTracker::Integrations::ActionController
end
# lib/correlation_tracker/integrations/action_controller.rb
module CorrelationTracker
  module Integrations
    module ActionController
      extend ActiveSupport::Concern

      included do
        before_action :set_correlation_user_context
      end

      private

      def set_correlation_user_context
        # Set user context if available
        if respond_to?(:current_user, true) && current_user
          CorrelationTracker::Context.user_id = current_user.id
        end
      end

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
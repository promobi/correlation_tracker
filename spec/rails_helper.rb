# spec/rails_helper.rb
# This file is required by specs that need a full Rails application setup.
# Since this is a gem, not a Rails app, we skip these specs by default.

require 'spec_helper'

RSpec.configure do |config|
  config.before(:each, type: :request) do
    skip "Skipping Rails integration tests - requires full Rails application setup"
  end
end

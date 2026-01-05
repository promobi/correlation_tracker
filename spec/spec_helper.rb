# spec/spec_helper.rb
require 'bundler/setup'
require 'correlation_tracker'
require 'rack/test'
require 'active_support'
require 'active_support/testing/time_helpers'
require 'ostruct'

# Load support files
Dir[File.expand_path('support/**/*.rb', __dir__)].sort.each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
    c.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # Run specs in random order to surface order dependencies
  config.order = :random
  Kernel.srand config.seed

  # Allow focusing on specific tests
  config.filter_run_when_matching :focus

  # Reset correlation context before each test
  config.before(:each) do
    CorrelationTracker.reset!
  end

  # Clean up after each test
  config.after(:each) do
    CorrelationTracker.reset!
  end

  # Include ActiveSupport test helpers
  config.include ActiveSupport::Testing::TimeHelpers
end

# Configure SimpleCov for code coverage
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/vendor/'
    minimum_coverage 90
  end
end
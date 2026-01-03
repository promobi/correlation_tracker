# lib/correlation_tracker/tasks/correlation_tracker.rake
namespace :correlation_tracker do
  desc "Show CorrelationTracker configuration"
  task config: :environment do
    config = CorrelationTracker.configuration

    puts "CorrelationTracker Configuration:"
    puts "================================="
    puts "Service Name: #{config.service_name}"
    puts "Header Name: #{config.header_name}"
    puts "Parent Header: #{config.parent_header_name}"
    puts "Fallback Headers: #{config.fallback_headers.join(', ')}"
    puts "Validate UUID: #{config.validate_uuid_format}"
    puts ""
    puts "Enabled Integrations:"
    config.integrations.each do |name, enabled|
      puts "  #{name}: #{enabled ? '✓' : '✗'}"
    end
  end

  desc "Test correlation ID generation"
  task test_generation: :environment do
    5.times do
      id = CorrelationTracker.generate_id
      puts "Generated: #{id}"
      puts "Valid: #{CorrelationTracker::Utilities::UuidValidator.valid?(id)}"
      puts ""
    end
  end
end
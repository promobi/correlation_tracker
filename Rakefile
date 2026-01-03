# Rakefile
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: [:spec, :rubocop]

desc 'Run tests with coverage'
task :coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task[:spec].invoke
end

desc 'Build and install gem locally'
task :install_local do
  system 'gem build correlation_tracker.gemspec'
  system 'gem install correlation_tracker-*.gem'
  system 'rm correlation_tracker-*.gem'
end

desc 'Generate documentation'
task :docs do
  system 'yard doc'
end

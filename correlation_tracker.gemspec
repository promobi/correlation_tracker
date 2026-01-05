# correlation_tracker.gemspec
require_relative 'lib/correlation_tracker/version'

Gem::Specification.new do |spec|
  spec.name          = 'correlation_tracker'
  spec.version       = CorrelationTracker::VERSION
  spec.authors       = ['ProMobi Technologies']
  spec.email         = ['noreply[at]promobitech[dot]com']

  spec.summary       = 'Distributed request correlation tracking for Ruby on Rails applications'
  spec.description   = <<-DESC
    Track requests across microservices with correlation IDs. 
    Supports Rails, Sidekiq, Kafka, and multiple HTTP clients.
    Provides automatic propagation through HTTP requests, background jobs, 
    and message queues with zero configuration.
  DESC

  spec.homepage      = 'https://github.com/promobi/correlation_tracker'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.3.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['documentation_uri'] = "#{spec.homepage}/blob/main/README.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) ||
      f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)}) ||
      f.end_with?('.sh')
    end
  end

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Core dependencies
  spec.add_dependency 'activesupport', '>= 6.0'
  spec.add_dependency 'railties', '>= 6.0'

  # Development dependencies
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec-rails', '~> 5.0'
  spec.add_development_dependency 'rack-test', '~> 2.0'
  spec.add_development_dependency 'simplecov', '~> 0.21'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'rubocop-rails', '~> 2.19'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.20'
  spec.add_development_dependency 'activejob', '>= 6.0'
end

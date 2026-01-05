# Correlation Tracker Ruby Gem

This is a Ruby gem for distributed request correlation tracking for Ruby on Rails applications.

## Project Structure

Directories:

- `lib/` - Main library code
  - `correlation_tracker.rb` - Primary entry point of the Ruby gem
  - `correlation_tracker/` - Library code
    - `extractors/` - `X-Correlation-Id` header extractor
    - `integrations/` - Integrations with several Rails components to seamlessly integrate correlation tracking
    - `integrations/http_clients` - HTTP Client library integrations
    - `middleware/` - Rails middleware integration
    - `tasks/` - Rake tasks to view configurations
    - `utilities/` - Logging utility and UUID format validator
    - `generators/` - Generates config file in Rails initializer folder
    - `context.rb` - Thread-local storage of correlation id
- `spec` - RSpec test suite
  - `integration/` - Integration tests
  - `support/` - Shared examples etc.

Files:

- `Gemfile`: Development dependencies
- `Rakefile`: Build and development tasks
- `correlation_tracker.gemspec`: Gem specification


### Framework Support

This gem supports Ruby on Rails framework.

### Testing

```bash
# Run the test suite
bundle exec rspec
```
# CorrelationTracker Installation Guide

## Quick Install

### From Local Gem
```bash
# Extract the package
tar -xzf correlation_tracker-1.0.0.tar.gz
cd correlation_tracker-1.0.0

# Build and install
gem build correlation_tracker.gemspec
gem install correlation_tracker-1.0.0.gem
```

### In Your Rails App

Add to `Gemfile`:
```ruby
gem 'correlation_tracker', path: '/path/to/correlation_tracker-1.0.0'
```

Then:
```bash
bundle install
rails generate correlation_tracker:install
```

## Verify Installation
```bash
ruby verify_installation.rb
```

## Configuration

Edit `config/initializers/correlation_tracker.rb` to customize:

- Service name
- Header names
- ID generation strategy
- Enabled integrations

## Testing
```bash
# Run gem tests
cd /path/to/correlation_tracker-1.0.0
bundle install
bundle exec rspec
```

## Documentation

See `README.md` for complete documentation.

## Support

- Issues: https://github.com/yourorg/correlation_tracker/issues
- Docs: https://github.com/yourorg/correlation_tracker
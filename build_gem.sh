#!/bin/bash
# build_gem.sh - Script to build the CorrelationTracker gem

set -e

echo "Building CorrelationTracker gem..."

# Clean previous builds
rm -rf pkg/
rm -f *.gem

# Create directory structure
mkdir -p lib/correlation_tracker/{middleware,extractors,integrations/http_clients,utilities,tasks}
mkdir -p lib/generators/correlation_tracker/templates
mkdir -p spec/{middleware,extractors,integrations,utilities}

echo "✓ Directory structure created"

# Build the gem
gem build correlation_tracker.gemspec

echo "✓ Gem built successfully\n"

# Display the result
ls -lh *.gem

echo ""
echo "Installation instructions:"
echo "  gem install correlation_tracker-1.0.0.gem"
echo ""
echo "Or add to your Gemfile:"
echo "  gem 'correlation_tracker', path: '$(pwd)'"
echo ""
echo "Then run:"
echo "  bundle install"
echo "  rails generate correlation_tracker:install"

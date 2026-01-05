# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-30

### Added
- Initial release
- Automatic correlation ID tracking for Rails applications
- Integration with ActionController (automatic)
- Integration with ActiveJob (automatic)
- Integration with Sidekiq (client and server middleware)
- Integration with Kafka (producer and consumer)
- Integration with HTTP clients (Faraday, HTTParty, Net::HTTP)
- Integration with Lograge (structured logging)
- Optional OpenTelemetry integration
- Configurable extractors for HTTP, webhooks, and email links
- UUID v4 and v7 support
- Thread-safe context storage using CurrentAttributes
- Comprehensive test suite
- Generator for initial setup (`rails g correlation_tracker:install`)
- Rake tasks for configuration and testing
- Complete documentation and examples

### Features
- Zero-configuration operation with sensible defaults
- Automatic propagation through HTTP, jobs, and message queues
- Webhook source auto-detection (Stripe, GitHub, Shopify, etc.)
- Support for parent-child correlation relationships
- Custom metadata support
- Temporary correlation context (`with_correlation`)
- UUID format validation
- Configurable headers and fallbacks
- Multiple origin type support (http, api, webhook, cron, etc.)

## [Unreleased]

### Added
- `track_correlation` method as an alias for `with_correlation` for more intuitive API

### Fixed
- **BREAKING BUG FIX**: `with_correlation` now properly restores ALL context attributes after block execution, not just the three core attributes (correlation_id, parent_correlation_id, origin_type)
  - Previously, attributes like user_id, customer_id, job_name, and custom metadata would persist after the block, causing context pollution
  - Now all attributes and metadata are fully restored to their previous state, even when exceptions occur
  - Nested blocks work correctly with proper context restoration at each level
  - This fix ensures true isolation for temporary correlation contexts

### Planned
- gRPC integration
- GraphQL integration
- AWS Lambda integration
- Azure Functions integration
- Additional HTTP client integrations
- Performance optimizations
- Enhanced webhook extractors

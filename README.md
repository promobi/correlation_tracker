# CorrelationTracker

Track requests across microservices with correlation IDs. Seamlessly integrates with Rails, Sidekiq, Kafka, and popular HTTP clients.

## Features

- 🔄 **Automatic Propagation** - Correlation IDs flow through HTTP, jobs, and message queues
- 🎯 **Zero Configuration** - Works out of the box with sensible defaults
- 🔌 **Plug & Play** - Integrates with Rails, Sidekiq, Kafka, Faraday, HTTParty
- 📊 **OpenTelemetry** - Optional integration for distributed tracing
- 🧪 **Test Friendly** - Easy to test with helpers and utilities

## Installation

Add to your Gemfile:
```ruby
gem 'correlation_tracker'
```

Install:
```bash
bundle install
rails generate correlation_tracker:install
```

## Usage

### Basic Usage

Correlation IDs are automatically tracked across:
- HTTP requests
- Background jobs (ActiveJob, Sidekiq)
- Kafka messages
- Outbound HTTP calls

No code changes needed! Just install and go.

### Manual Access
```ruby
# Get current correlation ID
CorrelationTracker.current_id
# => "550e8400-e29b-41d4-a716-446655440000"

# Get all context
CorrelationTracker.to_h
# => {
#   correlation_id: "550e8400-e29b-41d4-a716-446655440000",
#   parent_correlation_id: "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
#   origin_type: "http",
#   user_id: 42
# }

# Set custom context (for cron jobs, etc.)
CorrelationTracker.set(
  origin_type: 'cron',
  job_name: 'daily_report'
)

# Execute with temporary correlation (automatically restores previous context)
CorrelationTracker.with_correlation(correlation_id: 'temp-id') do
  # Your code here
  # All context (including metadata) automatically restored after block
end

# Or use the more intuitive alias:
CorrelationTracker.track_correlation do
  # Auto-generates new correlation ID
  # Your code here
  # Previous context fully restored when done
end
```

### Controllers

Automatic! No code needed.
```ruby
class OrdersController < ApplicationController
  def create
    # Correlation ID automatically available
    order = Order.create!(order_params)
    
    # Jobs inherit correlation automatically
    OrderProcessingJob.perform_later(order.id)
    
    render json: order
  end
end
```

### Background Jobs

Automatic with ActiveJob and Sidekiq!
```ruby
class OrderProcessingJob < ApplicationJob
  def perform(order_id)
    # Correlation ID automatically set
    order = Order.find(order_id)
    
    # HTTP calls auto-propagate correlation
    PaymentService.charge(order.amount)
  end
end
```

### Kafka

#### Producer
```ruby
kafka = Kafka.new(['localhost:9092'])
producer = kafka.producer

# Correlation headers automatically added
producer.produce('value', topic: 'events')
producer.deliver_messages
```

#### Consumer
```ruby
kafka = Kafka.new(['localhost:9092'])
consumer = kafka.consumer(group_id: 'my-consumer')

consumer.subscribe('events')

consumer.each_message do |message|
  # Correlation automatically extracted and set
  puts CorrelationTracker.current_id
  
  # Process message
end
```

### HTTP Clients

#### Faraday
```ruby
connection = Faraday.new do |f|
  f.request :correlation_tracker  # Add this line
  f.adapter Faraday.default_adapter
end

# Correlation headers automatically added
connection.get('/api/resource')
```

#### HTTParty
```ruby
class MyApiClient
  include HTTParty
  include CorrelationTracker::Integrations::HttpClients::HTTPartyIntegration
end

# Correlation headers automatically added
MyApiClient.get('/api/resource')
```

#### Net::HTTP

Automatic! No changes needed.
```ruby
Net::HTTP.get(URI('http://example.com'))
# Correlation headers automatically added
```

### Cron Jobs / Rake Tasks
```ruby
namespace :reports do
  task daily: :environment do
    # Set correlation context
    CorrelationTracker.set(
      origin_type: 'cron',
      job_name: 'daily_report'
    )

    ReportGenerator.generate
  end
end
```

### Temporary Correlation Context

Use `track_correlation` (or `with_correlation`) to execute code with a temporary correlation context. The previous context is fully restored after the block, including all metadata and custom attributes.

```ruby
# Basic usage - auto-generates correlation ID
CorrelationTracker.track_correlation do
  # Code here runs with new correlation ID
  PaymentService.process_payment(order)
end
# Previous correlation context restored

# With custom attributes
CorrelationTracker.track_correlation(
  correlation_id: 'batch-123',
  origin_type: 'batch',
  user_id: 42
) do
  # Process with custom correlation
  BatchProcessor.run
end

# Nested contexts work perfectly
CorrelationTracker.track_correlation(correlation_id: 'outer') do
  # Outer context

  CorrelationTracker.track_correlation(correlation_id: 'inner') do
    # Inner context
  end

  # Outer context automatically restored
end

# Exception handling - context always restored
CorrelationTracker.set(user_id: 100)

CorrelationTracker.track_correlation(user_id: 200) do
  raise "Something went wrong"
end rescue nil

CorrelationTracker::Context.user_id  # => 100 (restored despite exception)
```

## Configuration

```ruby
# config/initializers/correlation_tracker.rb
CorrelationTracker.configure do |config|
  # Service name (appears in logs)
  config.service_name = 'my-service'

  # HTTP headers
  config.header_name        = 'X-Correlation-ID'
  config.parent_header_name = 'X-Parent-Correlation-ID'
  config.fallback_headers   = %w[X-Request-ID X-Trace-ID]

  # ID generation
  config.uuid_version = 7

  # Kafka headers
  config.kafka_header_key        = 'correlation_id'
  config.kafka_parent_header_key = 'parent_correlation_id'

  # Enable/disable integrations
  config.enable_integration(:action_controller)
  config.enable_integration(:active_job)
  config.enable_integration(:lograge)
  config.enable_integration(:sidekiq)
  config.enable_integration(:kafka)
  config.enable_integration(:http_clients)
  config.enable_integration(:opentelemetry) # optional

  # Validation
  config.validate_uuid_format = true
end
```

## UUID Version Support

CorrelationTracker supports both UUID v4 and UUID v7:

### UUID v4 (Random)
- Default version
- Cryptographically random
- No time information
- Compatible with all Ruby versions

### UUID v7 (Time-ordered)
- Sortable by creation time
- Contains millisecond-precision timestamp
- Better for database indexing
- Requires Ruby 3.3+ (or uses fallback implementation)

### Configuration
```ruby
# Use UUID v7
CorrelationTracker.configure do |config|
  config.uuid_version = 7
end

# Or use UUID v4 (default)
CorrelationTracker.configure do |config|
  config.uuid_version = 4
end
```

### Benefits of UUID v7

1. **Time-ordered**: UUIDs are sortable by creation time
2. **Database-friendly**: Better B-tree index performance
3. **Debuggable**: Can extract timestamp from ID
4. **Efficient**: Reduces index fragmentation

### Utility Methods
```ruby
# Validate specific version
UuidValidator.valid?(uuid, version: 7)  # => true/false

# Detect version
UuidValidator.version(uuid)  # => 7

# Extract timestamp (v7 only)
UuidValidator.extract_timestamp(uuid)  # => Time object

# Compare UUIDs (v7 uses timestamp)
UuidValidator.compare(uuid1, uuid2)  # => -1, 0, or 1

# Generate specific version
UuidValidator.generate(7)  # => UUID v7 string
```

## Testing
```ruby
RSpec.describe MyController do
  it 'processes with correlation' do
    correlation_id = CorrelationTracker.set(correlation_id: 'test-123')
    
    get :index
    
    expect(CorrelationTracker.current_id).to eq('test-123')
    expect(response.headers['X-Correlation-ID']).to eq('test-123')
  end
end
```

## ClickHouse Queries
```sql
-- Trace a request across services
SELECT 
  timestamp,
  service_name,
  message,
  duration_ms
FROM logs
WHERE correlation_id = 'your-correlation-id'
ORDER BY timestamp;

-- Find broken traces
SELECT 
  correlation_id,
  count(DISTINCT service_name) as service_count,
  groupArray(service_name) as services
FROM logs
WHERE timestamp >= now() - INTERVAL 1 HOUR
GROUP BY correlation_id
HAVING service_count = 1;
```

## Contributing

Bug reports and pull requests are welcome on GitHub.

## License

The gem is available as open source under the terms of the MIT License.
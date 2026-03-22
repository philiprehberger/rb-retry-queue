# philiprehberger-retry_queue

[![Tests](https://github.com/philiprehberger/rb-retry-queue/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-retry-queue/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-retry_queue.svg)](https://rubygems.org/gems/philiprehberger-retry_queue)
[![License](https://img.shields.io/github/license/philiprehberger/rb-retry-queue)](LICENSE)

Batch processor with per-item retry, backoff, and dead letter collection

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-retry_queue"
```

Or install directly:

```bash
gem install philiprehberger-retry_queue
```

## Usage

```ruby
require "philiprehberger/retry_queue"

result = Philiprehberger::RetryQueue.process(items, max_retries: 3) do |item|
  process_item(item)
end

puts result.succeeded.size  # => number of successful items
puts result.failed.size     # => number of failed items
```

### Custom Backoff

```ruby
result = Philiprehberger::RetryQueue.process(items, max_retries: 5, backoff: ->(n) { n * 0.5 }) do |item|
  external_api_call(item)
end
```

### Dead Letter Inspection

```ruby
result = Philiprehberger::RetryQueue.process(jobs, max_retries: 2) do |job|
  job.execute!
end

result.failed.each do |entry|
  puts "Item: #{entry[:item]}, Error: #{entry[:error].message}, Attempts: #{entry[:attempts]}"
end
```

### Statistics

```ruby
result = Philiprehberger::RetryQueue.process(records, max_retries: 3) do |record|
  save(record)
end

stats = result.stats
# => { total: 100, succeeded: 97, failed: 3, success_rate: 0.97, elapsed: 1.23 }
```

## API

| Method | Description |
|--------|-------------|
| `.process(items, max_retries:, concurrency:, backoff:) { \|item\| }` | Process items with retry logic |
| `Result#succeeded` | Array of successfully processed items |
| `Result#failed` | Array of hashes with `:item`, `:error`, `:attempts` |
| `Result#stats` | Hash with `:total`, `:succeeded`, `:failed`, `:success_rate`, `:elapsed` |

## Development

```bash
bundle install
bundle exec rspec      # Run tests
bundle exec rubocop    # Check code style
```

## License

MIT

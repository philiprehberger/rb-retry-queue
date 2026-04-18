# philiprehberger-retry_queue

[![Tests](https://github.com/philiprehberger/rb-retry-queue/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-retry-queue/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-retry_queue.svg)](https://rubygems.org/gems/philiprehberger-retry_queue)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-retry-queue)](https://github.com/philiprehberger/rb-retry-queue/commits/main)

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

### Selective Retry

```ruby
result = Philiprehberger::RetryQueue.process(items, max_retries: 3, retry_on: [Net::OpenTimeout, Timeout::Error]) do |item|
  api_call(item)
end

# Only Net::OpenTimeout and Timeout::Error trigger retries
# All other errors send the item straight to failed
```

### Retry Hooks

```ruby
logger_hook = ->(item, error, attempt) { puts "Retrying #{item}: #{error.message} (attempt #{attempt})" }
metrics_hook = ->(item, _error, _attempt) { increment_counter("retry.#{item}") }

result = Philiprehberger::RetryQueue.process(items, max_retries: 3, on_retry: [logger_hook, metrics_hook]) do |item|
  process_item(item)
end
```

### Dead-letter Notifications

```ruby
on_failure = ->(item, error) { Rails.logger.error("Dead-lettered #{item}: #{error.message}") }

result = Philiprehberger::RetryQueue.process(items, max_retries: 3, on_failure: on_failure) do |item|
  process_item(item)
end
```

The hook fires once per item that exhausts its retries, just as the item is recorded in
`Result#failed`. Exceptions raised inside the hook are swallowed so a faulty callback cannot
break the queue.

### DLQ Reprocessing

```ruby
result = Philiprehberger::RetryQueue.process(jobs, max_retries: 2) do |job|
  job.execute!
end

reprocessed = result.reprocess_failed do |item, error|
  fallback_handler(item, error)
end

puts reprocessed.succeeded.size  # => items recovered during reprocessing
puts reprocessed.failed.size     # => items that failed reprocessing too
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
| `.process(items, max_retries:, concurrency:, backoff:, retry_on:, on_retry:, on_failure:) { \|item\| }` | Process items with retry logic |
| `on_failure:` | Callable `(item, error)` invoked once per item that exhausts retries; hook errors are swallowed |
| `Result#succeeded` | Array of successfully processed items |
| `Result#failed` | Array of hashes with `:item`, `:error`, `:attempts` |
| `Result#stats` | Hash with `:total`, `:succeeded`, `:failed`, `:success_rate`, `:elapsed` |
| `Result#reprocess_failed { \|item, error\| }` | Reprocess failed items, returns a new Result |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-retry-queue)

🐛 [Report issues](https://github.com/philiprehberger/rb-retry-queue/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-retry-queue/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)

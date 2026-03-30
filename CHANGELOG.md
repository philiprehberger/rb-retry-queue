# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-03-29

### Added
- Selective retry via `retry_on:` parameter to only retry specific exception classes
- Retry hooks via `on_retry:` parameter with callbacks fired before each retry attempt
- DLQ reprocessing via `Result#reprocess_failed` to iterate over failed items with their last error

## [0.1.2] - 2026-03-24

### Fixed
- Remove inline comments from Development section to match template

## [0.1.1] - 2026-03-22

### Changed

- Expand test coverage to 30+ examples covering single item processing, all-succeed/all-fail scenarios, max retries reached, backoff calculation, custom error types, dead letter collection, attempt ordering, and edge cases

## [0.1.0] - 2026-03-22

### Added
- Initial release
- Batch processing with per-item retry and configurable max retries
- Exponential backoff with custom backoff strategy support
- Dead letter collection for items that exhaust retries
- Result object with succeeded, failed, and stats accessors
- Timing statistics with elapsed duration and success rate

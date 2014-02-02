# frozen_string_literal: true

require_relative 'lib/philiprehberger/retry_queue/version'

Gem::Specification.new do |spec|
  spec.name          = 'philiprehberger-retry_queue'
  spec.version       = Philiprehberger::RetryQueue::VERSION
  spec.authors       = ['Philip Rehberger']
  spec.email         = ['me@philiprehberger.com']

  spec.summary       = 'Batch processor with per-item retry, backoff, and dead letter collection'
  spec.description   = 'Processes collections of items with configurable per-item retry logic, ' \
                       'exponential backoff, and dead letter collection for failed items. ' \
                       'Returns detailed results with success/failure counts and timing statistics.'
  spec.homepage      = 'https://github.com/philiprehberger/rb-retry-queue'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = spec.homepage
  spec.metadata['changelog_uri']         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri']       = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end

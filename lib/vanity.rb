require "date"
require "time"
require "logger"

# All the cool stuff happens in other places.
# @see Vanity::Helper
# @see Vanity::Rails
# @see Vanity::Playground
# @see Vanity::Metric
# @see Vanity::Experiment
module Vanity
  # Version number.
  module Version
    version = Gem::Specification.load(File.expand_path("../vanity.gemspec", File.dirname(__FILE__))).version.to_s.split(".").map { |i| i.to_i }
    MAJOR = version[0]
    MINOR = version[1]
    PATCH = version[2]
    STRING = "#{MAJOR}.#{MINOR}.#{PATCH}"
  end

end

require "vanity/backport" if RUBY_VERSION < "1.9"
# Metrics.
require "vanity/metric/base"
require "vanity/metric/active_record"
require "vanity/metric/google_analytics"
# Experiments.
require "vanity/experiment/base"
require "vanity/experiment/ab_test"
# Database adapters
require "vanity/adapters/abstract_adapter"
require "vanity/adapters/redis_adapter"
require "vanity/adapters/mock_adapter"
# Playground.
require "vanity/playground"
require "vanity/helpers"
# Integration with various frameworks.
require "vanity/frameworks/rails" if defined?(Rails)

require "date"
require "time"
require "logger"
require "cgi"
require "erb"
require "yaml"

# All the cool stuff happens in other places.
# @see Vanity::Helper
# @see Vanity::Rails
# @see Vanity::Playground
# @see Vanity::Metric
# @see Vanity::Experiment
module Vanity
end

require "vanity/version"
# Metrics.
require "vanity/metric/base"
require "vanity/metric/active_record"
require "vanity/metric/google_analytics"
require "vanity/metric/remote"
# Experiments.
require "vanity/experiment/base"
require "vanity/experiment/ab_test"
# Database adapters
require "vanity/adapters"
require "vanity/adapters/abstract_adapter"
require "vanity/adapters/mock_adapter"
# Playground.
require "vanity/playground"
require "vanity/templates"
require "vanity/autoconnect"
require "vanity/helpers"
# Integration with various frameworks.
require "vanity/frameworks"

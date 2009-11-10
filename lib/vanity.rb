require "redis"
require "openssl"

# All the cool stuff happens in other places:
# - Vanity::Helpers
# - Vanity::Playground
# - Experiment::AbTest
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


require File.join(File.dirname(__FILE__), "vanity/playground")
require File.join(File.dirname(__FILE__), "vanity/experiment/base")
require File.join(File.dirname(__FILE__), "vanity/experiment/ab_test")

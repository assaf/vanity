require "redis"
require "openssl"

# All the cool stuff happens in other places:
# - Playground
# - Experiment::Base
module Vanity
  # Version number.
  module Version
    STRING = Gem::Specification.load(File.expand_path("../vanity.gemspec", File.dirname(__FILE__))).version.to_s.freeze
    MAJOR, MINOR, PATCH = STRING.split(".").map { |i| i.to_i }
  end
end

require File.join(File.dirname(__FILE__), "vanity/playground")
require File.join(File.dirname(__FILE__), "vanity/experiment/base")
require File.join(File.dirname(__FILE__), "vanity/experiment/ab_test")

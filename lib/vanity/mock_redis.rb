require "vanity/store/mock"

module Vanity
  # @deprecated Please use Vanity::Store::Mock instead.
  MockRedis = Vanity::Store::Mock
  warn "Deprecated: please use Vanity::Store::Mock instead"
end

require_relative "gemvault/version"
require_relative "gemvault/vault"

##
# Top-level namespace for the gemvault gem.
module Gemvault
  ##
  # Base error class for gemvault.
  class Error < StandardError; end
end

require_relative "gemvault/version"
require_relative "gemvault/deprecation"
require_relative "gemvault/vault"
require_relative "gemvault/vault_path"

##
# Top-level namespace for the gemvault gem.
module Gemvault
  ##
  # Base error class for gemvault.
  class Error < StandardError; end
end

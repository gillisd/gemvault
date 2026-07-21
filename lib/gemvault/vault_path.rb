require "uri"
require "pathname"

module Gemvault
  ##
  # Translates vault locators into filesystem paths.
  #
  # A locator is whatever a user hands the CLI or a package manager as "the
  # vault": a plain filesystem path, a <tt>file://</tt> URI, or a
  # <tt>vault://</tt> URI. Anything else passes through unchanged.
  module VaultPath
    SCHEMES = ["file", "vault"].freeze

    module_function

    # :call-seq:
    #   resolve(locator) -> Pathname
    #
    # Resolves +locator+ to a Pathname. Two-slash relative forms such as
    # <tt>file://vault.gemv</tt> parse their first segment as a URI host, so
    # host and path are rejoined.
    def resolve(locator)
      begin
        uri = URI.parse(locator.to_s)
        return Pathname(locator.to_s) unless SCHEMES.include?(uri.scheme)

        Pathname([uri.host, uri.path].compact.join)
      rescue URI::InvalidURIError
        Pathname(locator.to_s)
      end
    end
  end
end

require "uri"

module Gemvault
  ##
  # Translates vault locators into filesystem paths.
  #
  # A locator is whatever a user hands the CLI or a package manager as "the
  # vault": a plain filesystem path, a <tt>file://</tt> URI, or a
  # <tt>vault://</tt> URI. Anything else passes through unchanged.
  module VaultPath
    SCHEMES = ["file", "vault"].freeze

    # :call-seq:
    #   resolve(locator) -> String
    #
    # Resolves +locator+ to a filesystem path. Two-slash relative forms such
    # as <tt>file://vault.gemv</tt> parse their first segment as a URI host,
    # so host and path are rejoined.
    def self.resolve(locator)
      uri = URI.parse(locator.to_s)
      return locator.to_s unless SCHEMES.include?(uri.scheme)

      [uri.host, uri.path].compact.join
    rescue URI::InvalidURIError
      locator.to_s
    end
  end
end

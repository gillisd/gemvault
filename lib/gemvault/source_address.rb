module Gemvault
  ##
  # The address a Gemfile uses to name a vault as an ordinary gem source, such
  # as <tt>https://gemvault.invalid/vendor/private.gemv/</tt>.
  #
  # The host is reserved and resolves nowhere; everything after it is the
  # vault's path relative to the Gemfile. Because the address is a plain gem
  # server URL, the Gemfile and its lockfile carry no plugin source, which is
  # what lets tools that evaluate a Gemfile without installing Bundler plugins
  # (Dependabot among them) read both files.
  #
  # Deliberately requires nothing, the +uri+ library included: this loads
  # inside a Bundler process, where requiring a default gem can activate a
  # version the bundle has locked differently.
  class SourceAddress
    HOST = "gemvault.invalid".freeze
    PATTERN = %r{\Ahttps://#{Regexp.escape(HOST)}/(?<vault_path>[^?#]*[^/?#])/?\z}

    ##
    # Whether +address+ names a vault.
    def self.vaulted?(address)
      PATTERN.match?(address.to_s)
    end

    ##
    # The address that names the vault at +vault_path+.
    def self.for(vault_path)
      new("https://#{HOST}/#{vault_path}/")
    end

    ##
    # The vault's path, relative to the Gemfile that named it.
    attr_reader :vault_path

    def initialize(address)
      located = PATTERN.match(address.to_s)
      raise ArgumentError, "#{address} does not address a vault" unless located

      @vault_path = located[:vault_path]
    end

    def to_s
      "https://#{HOST}/#{@vault_path}/"
    end
  end
end

require_relative "static_index"

module Gemvault
  ##
  # A vault kept published as a static gem index on a shelf: a directory that
  # holds exactly one index, for the vault as it currently stands.
  #
  # The index sits in a folder named for the vault file's size and modification
  # time, so an unchanged vault is recognised by a single +stat+ and a changed
  # one is published afresh, replacing the index it supersedes.
  #
  # This runs inside whatever process evaluates a Gemfile, before Bundler has
  # set up the bundle. Anything required here is activated at whatever version
  # happens to be installed, and a bundle that locks a different version then
  # fails to load. Reading gem packages needs zlib, openssl and a dozen other
  # default gems, so the publishing itself happens in a separate Ruby process;
  # this class loads nothing and activates nothing.
  #
  # That process must never come back here. RubyGems loads Bundler into any
  # Ruby started with BUNDLER_SETUP set, which would evaluate the Gemfile, find
  # the index still unpublished and start another process, without end. Every
  # variable that pulls Bundler in is cleared for the child, and the child is
  # marked so that a publication asked for from inside it is refused outright.
  class VaultPublication
    SCRIPT = File.expand_path("publish_static_index.rb", __dir__).freeze
    PUBLISHING = "GEMVAULT_PUBLISHING".freeze
    BUNDLER_VARIABLES = %w[
      RUBYOPT RUBYLIB RUBYGEMS_GEMDEPS BUNDLER_SETUP BUNDLE_GEMFILE BUNDLE_LOCKFILE BUNDLE_BIN_PATH
    ].freeze
    OUTSIDE_THE_BUNDLE = BUNDLER_VARIABLES.to_h { |variable| [variable, nil] }.merge(PUBLISHING => "1").freeze

    ##
    # Raised when the vault could not be published.
    class Error < StandardError; end

    def initialize(vault_path, shelf:)
      @vault_path = vault_path.to_s
      @shelf = shelf.to_s
    end

    ##
    # The index for the vault as it stands, published first if it is not
    # already on the shelf.
    def publish
      index = StaticIndex.new(File.join(@shelf, stamp))
      return index if index.published?
      raise Error, "already publishing #{@vault_path}; refusing to start again" if ENV.key?(PUBLISHING)

      shelve(index)
    end

    private

    def stamp
      stat = File.stat(@vault_path)
      modified = stat.mtime

      "#{stat.size}-#{modified.to_i}-#{modified.nsec}"
    end

    def shelve(index)
      return index if system(OUTSIDE_THE_BUNDLE, Gem.ruby, SCRIPT, @vault_path, @shelf, index.directory)

      raise Error, "could not publish #{@vault_path} as a gem index"
    end
  end
end

require_relative "shelf"

module Gemvault
  ##
  # A vault kept published as a static gem index on a shelf: a directory that
  # holds exactly one index, for the vault as it currently stands.
  #
  # The index sits in a folder named for the vault file's size and modification
  # time, so an unchanged vault is recognised without opening it and a changed
  # one is published afresh, replacing the index it supersedes.
  #
  # This runs inside whatever process evaluates a Gemfile, before Bundler has
  # set up the bundle. Anything required here is activated at whatever version
  # happens to be installed, and a bundle that locks a different version then
  # fails to load. Reading gem packages needs zlib, openssl and other default
  # gems, so the publishing itself happens in a separate Ruby process; this
  # class requires no gem and activates nothing.
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
      @shelf = shelf
    end

    ##
    # The index for the vault as it stands, published first if it is not
    # already on the shelf.
    def publish
      index = @shelf.index_for(stamp)
      return index if index.published?
      raise Error, "already publishing #{@vault_path}; refusing to start again" if ENV.key?(PUBLISHING)

      shelve(index)
    end

    private

    def stamp
      begin
        stat = File.stat(@vault_path)
      rescue SystemCallError => e
        raise Error, "could not read vault #{@vault_path}: #{e.message}"
      end

      "#{stat.size}-#{stat.mtime.to_i}-#{stat.mtime.nsec}"
    end

    def shelve(index)
      command = [Gem.ruby, SCRIPT, @vault_path, @shelf.directory, File.basename(index.directory)]

      begin
        said = IO.popen(OUTSIDE_THE_BUNDLE, command, err: %i[child out], &:read).scrub.strip
      rescue SystemCallError => e
        raise Error, "#{unpublished}: could not start #{Gem.ruby}: #{e.message}"
      end

      concluded(index, Process.last_status, said)
    end

    def concluded(index, status, said)
      raise Error, "#{unpublished}: the publishing process was killed by signal #{status.termsig}" if status.signaled?
      raise Error, "#{unpublished}: #{said}" unless status.success?

      warn said unless said.empty?
      index
    end

    def unpublished
      "could not publish #{@vault_path} as a gem index"
    end
  end
end

require "pathname"

module Gemvault
  ##
  # The Gemfile Bundler would load from a directory.
  #
  # Mirrors Bundler::SharedHelpers#find_gemfile: <tt>BUNDLE_GEMFILE</tt> wins
  # when set and non-empty, otherwise the search walks up looking for
  # <tt>gems.rb</tt> then <tt>Gemfile</tt> in each directory. Reimplemented
  # rather than delegated because bundler is deliberately not a gemvault
  # dependency (see gemvault.gemspec) and +gemvault doctor+ runs as a plain
  # CLI, outside any Bundler process.
  #
  # One difference is deliberate. Bundler returns <tt>BUNDLE_GEMFILE</tt>
  # whatever it points at, existing or not -- bundler/inline relies on that,
  # setting it to a bare "Gemfile" purely to make Bundler treat the working
  # directory as the app root. The question here is whether +bundle install+
  # could work, so a value that is not a file counts as no Gemfile.
  class BundlerGemfile
    # Checked in this order within each directory, as Bundler checks them.
    NAMES = ["gems.rb", "Gemfile"].freeze

    def initialize(dir: Dir.pwd, env: ENV)
      @dir = Pathname(dir)
      @env = env
    end

    # :call-seq:
    #   path -> Pathname or nil
    #
    # The Gemfile Bundler would load, or +nil+ when there is none.
    def path
      return @path if defined?(@path)

      @path = from_env || search_up
    end

    # Whether Bundler would find a Gemfile at all.
    def exist?
      !path.nil?
    end

    private

    def from_env
      given = @env["BUNDLE_GEMFILE"].to_s
      return nil if given.empty?

      candidate = Pathname(given).expand_path(@dir)
      candidate.file? ? candidate : nil
    end

    def search_up
      @dir.expand_path.ascend do |dir|
        found = NAMES.map { |name| dir / name }.find(&:file?)
        return found if found
      end

      nil
    end
  end
end

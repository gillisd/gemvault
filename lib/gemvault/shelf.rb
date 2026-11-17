require_relative "static_index"

module Gemvault
  ##
  # The directory a vault's index is published in. A shelf holds one current
  # index, in a folder named for the stamp of the vault it was published from,
  # and whatever else is on it is left alone.
  #
  # An index is written into a partial folder and renamed into place once it
  # is complete, under a lock on the shelf. A reader therefore never finds a
  # half-written index, and two publishers never write the same one.
  #
  # RubyGems and Bundler read a file address by its path exactly as written
  # and never decode it, so a shelf whose path would need escaping cannot be
  # reached through one.
  #
  # Asking a shelf where an index is, and whether it can be addressed or
  # written, loads no gem, so those are safe inside a Bundler process.
  # Stocking it is for the publishing process only.
  class Shelf
    STAMP = /\A\d+-\d+-\d+\z/
    SHELVED = /\A\d+-\d+-\d+(\.partial)?\z/
    LOCK = ".lock".freeze

    ##
    # Where the shelf is.
    attr_reader :directory

    def initialize(directory)
      @directory = directory.to_s
    end

    def to_s
      @directory
    end

    ##
    # The index for the vault that carries +stamp+, published or not.
    def index_for(stamp)
      raise ArgumentError, "#{stamp} is not a vault stamp" unless STAMP.match?(stamp)

      StaticIndex.new(File.join(@directory, stamp))
    end

    ##
    # Whether an index here can be both reached by a gem source address and
    # written.
    def usable?
      addressable? && writable?
    end

    ##
    # Whether a gem source address can carry this directory.
    def addressable?
      require "rubygems/vendor/uri/lib/uri" unless defined?(Gem::URI)

      begin
        Gem::URI.parse("file://#{@directory}/").path == "#{@directory}/"
      rescue Gem::URI::InvalidURIError
        false
      end
    end

    ##
    # Whether the directory exists and can be written, or could be created.
    def writable?
      existing = @directory
      existing = File.dirname(existing) until File.exist?(existing)

      File.directory?(existing) && File.writable?(existing)
    end

    ##
    # The published index for +stamp+. Unless it is already on the shelf, the
    # block is handed an index to publish into, which then replaces whatever
    # index the shelf held.
    def stock(stamp)
      current = index_for(stamp)

      locked do
        next if current.published?

        partial = cleared("#{current.directory}.partial")
        yield StaticIndex.new(partial)
        File.rename(partial, cleared(current.directory))
        discard_all_but(stamp)
      end

      current
    end

    private

    def locked(&)
      require "fileutils"

      FileUtils.mkdir_p(@directory)
      File.open(File.join(@directory, LOCK), File::RDWR | File::CREAT) do |lock|
        lock.flock(File::LOCK_EX)
        yield
      end
    end

    def cleared(path)
      FileUtils.rm_rf(path)

      path
    end

    def discard_all_but(stamp)
      Dir.children(@directory)
         .grep(SHELVED)
         .reject { |entry| entry == stamp }
         .each { |entry| discard(File.join(@directory, entry)) }
    end

    def discard(superseded)
      begin
        FileUtils.rm_r(superseded)
      rescue SystemCallError => e
        warn "gemvault: could not remove superseded index #{superseded}: #{e.message}"
      end
    end
  end
end

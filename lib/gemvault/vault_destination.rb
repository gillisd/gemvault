require "pathname"

module Gemvault
  ##
  # Where a new vault is about to be written: the <tt>.gemv</tt> path itself,
  # and the directories that have to exist before anything can be written to it.
  #
  # A vault is one file, so <tt>gemvault new vendor/vendored.gemv</tt> in a tree
  # that has no <tt>vendor</tt> yet reads as an ordinary request rather than a
  # mistake, and the missing directories are created. What cannot be papered
  # over -- something already occupying the path, a parent that is a file, a
  # parent that cannot be created -- is raised as Error, so the CLI reports one
  # line instead of a Ruby backtrace.
  class VaultDestination
    SUFFIX = ".gemv".freeze

    ##
    # Raised when the path cannot hold a new vault.
    class Error < StandardError; end

    # The vault's path, with SUFFIX appended if the name lacked it.
    attr_reader :path

    def initialize(name)
      locator = suffixed(name.to_s)
      @path = Pathname(locator)
    end

    # Raises Error when something already occupies the vault's path.
    def refuse_existing
      raise Error, "#{@path} already exists" if @path.exist?
    end

    # :call-seq:
    #   missing_directory -> Pathname or nil
    #
    # The shallowest directory create_parents would have to make -- creating it
    # brings every deeper one with it -- or +nil+ when the parent already
    # exists.
    def missing_directory
      @path.dirname.ascend.reject(&:exist?).last
    end

    # Creates the vault's missing parent directories.
    def create_parents
      parent = @path.dirname
      return if parent.directory?

      raise Error, "#{parent} is not a directory" if parent.exist?

      make(parent)
    end

    private

    def suffixed(locator)
      return locator if locator.end_with?(SUFFIX)

      "#{locator}#{SUFFIX}"
    end

    def make(parent)
      begin
        parent.mkpath
      rescue SystemCallError => e
        raise Error, "cannot create directory #{parent}: #{e.message}"
      end
    end
  end
end

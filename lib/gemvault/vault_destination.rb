require "pathname"

module Gemvault
  ##
  # Where a new vault is about to be written: the <tt>.gemv</tt> path itself,
  # and the directories that have to exist before anything can be written to it.
  #
  # A vault is one file, so <tt>gemvault new vendor/vendored.gemv</tt> in a tree
  # that has no <tt>vendor</tt> yet reads as an ordinary request rather than a
  # mistake, and the missing directories are created. What cannot be papered
  # over -- a parent that is a file, a parent that cannot be created -- is
  # raised as Error, so the CLI reports one line instead of a Ruby backtrace.
  class VaultDestination
    SUFFIX = ".gemv".freeze

    ##
    # Raised when the path cannot hold a vault.
    class Error < StandardError; end

    # The vault's path, with SUFFIX appended if the name lacked it.
    attr_reader :path

    def initialize(name)
      locator = name.to_s
      @path = Pathname(locator.end_with?(SUFFIX) ? locator : "#{locator}#{SUFFIX}")
    end

    # Whether something already occupies the vault's path.
    def exist?
      @path.exist?
    end

    # :call-seq:
    #   create_parents -> Pathname or nil
    #
    # Creates the vault's missing parent directories, answering the shallowest
    # one created so a caller can report it, or +nil+ when none were missing.
    def create_parents
      parent = @path.dirname
      return nil if parent.directory?

      raise Error, "#{parent} is not a directory" if parent.exist?

      shallowest_missing(parent).tap { make(parent) }
    end

    private

    # Pathname#ascend walks outward, so the last ancestor that does not exist is
    # the one whose creation brings all the others with it.
    def shallowest_missing(parent)
      parent.ascend.reject(&:exist?).last
    end

    def make(parent)
      parent.mkpath
    rescue SystemCallError => e
      raise Error, "cannot create directory #{parent}: #{e.message}"
    end
  end
end

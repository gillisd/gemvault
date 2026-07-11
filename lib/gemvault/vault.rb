require "forwardable"
require_relative "vault_session"

module Gemvault
  # The public vault interface. Delegates storage to a backend chosen by file
  # format: a Dbvault (SQLite) for existing SQLite files, otherwise a Tarvault
  # (tarball). New vaults are Tarvaults. Only the selected backend is loaded,
  # so the tar path never requires sqlite3.
  class Vault
    extend VaultSession
    extend Forwardable

    class Error < StandardError; end
    class NotFoundError < Error; end
    class DuplicateGemError < Error; end
    class InvalidGemError < Error; end

    SQLITE_MAGIC = "SQLite format 3#{0.chr}".freeze

    def_delegators :@backend,
                   :add, :remove, :gem_data, :gem_entries, :specs,
                   :spec_from_blob, :with_gem_file, :size, :close, :closed?, :path

    def self.backend_for(path, create:)
      if !create && sqlite?(path)
        require_relative "dbvault"
        Dbvault.new(path, create: create)
      else
        require_relative "tarvault"
        Tarvault.new(path, create: create)
      end
    end

    def self.sqlite?(path)
      File.exist?(path) && File.binread(path, SQLITE_MAGIC.bytesize) == SQLITE_MAGIC
    end

    def initialize(path, create: false)
      @backend = self.class.backend_for(File.expand_path(path), create: create)
    end
  end
end

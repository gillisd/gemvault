require "forwardable"
require_relative "vault_session"

module Gemvault
  # The public vault interface. Delegates storage to a backend chosen by file
  # format: a Dbvault (SQLite) for existing SQLite files, a Tarvault (tarball)
  # otherwise. New vaults are Tarvaults. Only the selected backend is loaded,
  # so the tar path never requires sqlite3.
  class Vault
    extend VaultSession
    extend Forwardable

    class Error < StandardError; end
    class NotFoundError < Error; end
    class DuplicateGemError < Error; end
    class InvalidGemError < Error; end
    class UnsupportedVersionError < Error; end

    SQLITE_MAGIC = "SQLite format 3#{0.chr}".freeze
    TAR_MAGIC = "ustar".freeze
    TAR_MAGIC_OFFSET = 257

    CURRENT_FORMAT = 2
    MIN_READABLE_FORMAT = 1

    def_delegators :@backend,
                   :add, :remove, :gem_data, :gem_entries, :specs,
                   :spec_from_blob, :with_gem_file, :size, :close, :closed?,
                   :path, :format_version

    def self.assert_readable!(version, path)
      return if version.between?(MIN_READABLE_FORMAT, CURRENT_FORMAT)

      raise UnsupportedVersionError,
            "Vault #{path} is format #{version}; this gemvault reads up to #{CURRENT_FORMAT}. Upgrade gemvault."
    end

    def self.backend_for(path, create:)
      return build_tarvault(path, create: true) if create
      raise NotFoundError, "Vault not found: #{path}" unless File.exist?(path)

      case container_kind(path)
      when :sqlite then build_dbvault(path)
      when :tar then build_tarvault(path, create: false)
      else
        raise Error, "Unrecognized vault format: #{path} (not a Dbvault or Tarvault; it may require a newer gemvault)"
      end
    end

    def self.container_kind(path)
      return :sqlite if sqlite?(path)
      return :tar if tar?(path)

      :unknown
    end

    def self.sqlite?(path)
      File.exist?(path) && File.binread(path, SQLITE_MAGIC.bytesize) == SQLITE_MAGIC
    end

    def self.tar?(path)
      return false unless File.exist?(path)

      header = File.binread(path, TAR_MAGIC_OFFSET + TAR_MAGIC.bytesize)
      header.to_s[TAR_MAGIC_OFFSET, TAR_MAGIC.bytesize] == TAR_MAGIC
    end

    def self.build_dbvault(path)
      require_relative "dbvault"
      Dbvault.new(path, create: false)
    rescue LoadError => e
      raise Error,
            "#{path} is a legacy SQLite vault; it needs the sqlite3 gem (#{e.message}). " \
            "Install sqlite3, or upgrade the vault with a gemvault that includes it."
    end

    def self.build_tarvault(path, create:)
      require_relative "tarvault"
      Tarvault.new(path, create: create)
    end

    def initialize(path, create: false)
      @backend = self.class.backend_for(File.expand_path(path), create: create)
    end
  end
end

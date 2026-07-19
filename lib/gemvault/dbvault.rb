require "sqlite3"
require "pathname"
require_relative "vault"
require_relative "vault_session"
require_relative "gem_extraction"
require_relative "gem_entry"
require_relative "deprecation"

module Gemvault
  # Read-only reader for a SQLite-backed vault (a "Dbvault"). Attempts to write
  # are refused with a pointer to run gemvault upgrade, and opening a vault
  # emits a one-time notice.
  class Dbvault
    extend VaultSession
    include GemExtraction

    FORMAT_VERSION = 1

    attr_reader :path

    def initialize(path)
      @path = Pathname(path).expand_path
      open_vault!
    end

    def add(*)
      raise Vault::ReadOnlyError, read_only_message
    end

    def remove(*)
      raise Vault::ReadOnlyError, read_only_message
    end

    def gem_data(entry)
      row = @db.execute(
        "SELECT data FROM gems WHERE name = ? AND version = ? AND platform = ?",
        [entry.name, entry.version, entry.platform],
      ).first
      raise Vault::NotFoundError, "Gem not found: #{entry}" unless row

      row["data"]
    end

    def gem_entries
      @db.execute(
        "SELECT name, version, platform, created_at FROM gems ORDER BY name, version",
      ).map { |row| GemEntry.new(**row.transform_keys(&:to_sym)) }
    end

    def size
      @db.execute("SELECT COUNT(*) AS count FROM gems").first["count"]
    end

    def close
      @db.close if @db && !@db.closed?
    end

    def closed?
      @db.nil? || @db.closed?
    end

    def format_version
      row = @db.execute("SELECT value FROM metadata WHERE key = 'vault_version'").first
      return FORMAT_VERSION unless row

      row["value"].to_i
    end

    private

    def open_vault!
      raise Vault::NotFoundError, "Vault not found: #{@path}" unless @path.exist?

      validate_sqlite!
      @db = new_database
      Vault.assert_readable!(version: format_version, path: @path)
      Deprecation.warn_once(deprecation_message)
    end

    def new_database
      db = SQLite3::Database.new(@path.to_s)
      db.results_as_hash = true
      db
    end

    def validate_sqlite!
      return if @path.binread(Vault::SQLITE_MAGIC.bytesize) == Vault::SQLITE_MAGIC

      raise Vault::Error, "Not a valid vault file (not SQLite): #{@path}"
    end

    def read_only_message
      "#{@path} uses the deprecated read-only SQLite format. Migrate it first: gemvault upgrade #{@path}"
    end

    def deprecation_message
      "SQLite vaults are deprecated and read-only; support will be removed in a future release (0.3-0.5). " \
        "Migrate #{@path} with: gemvault upgrade #{@path}"
    end
  end
end

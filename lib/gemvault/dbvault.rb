require "sqlite3"
require "rubygems/package"
require_relative "vault"
require_relative "vault_session"
require_relative "gem_extraction"
require_relative "gem_entry"
require_relative "gem_reference"
require_relative "deprecation"

module Gemvault
  # SQLite-backed vault (a "Dbvault"): stores .gem blobs and metadata in a
  # single SQLite database file.
  class Dbvault
    extend VaultSession
    include GemExtraction

    FORMAT_VERSION = 1

    attr_reader :path

    def initialize(path, create: false)
      @path = File.expand_path(path)
      @writable = create
      create ? create_vault! : open_vault!
    end

    def add(gem_path, created_at: nil)
      ensure_writable!
      gem_path = File.expand_path(gem_path)
      raise Vault::NotFoundError, "Gem file not found: #{gem_path}" unless File.file?(gem_path)

      spec = spec_from_gem_file(gem_path)
      raise_if_duplicate(spec)
      insert_gem(gem_path, spec, created_at || timestamp)
    end

    def remove(reference)
      ensure_writable!
      case reference
      in GemReference::AnyVersion[name:]
        @db.execute("DELETE FROM gems WHERE name = ?", [name])
      in GemReference::SpecificVersion[name:, version:]
        @db.execute("DELETE FROM gems WHERE name = ? AND version = ?", [name, version.to_s])
      end
      @db.changes
    end

    def gem_data(name, version, platform: "ruby")
      row = @db.execute(
        "SELECT data FROM gems WHERE name = ? AND version = ? AND platform = ?",
        [name, version, platform],
      ).first
      raise Vault::NotFoundError, "Gem not found: #{name}-#{version} (#{platform})" unless row

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
      row ? row["value"].to_i : FORMAT_VERSION
    end

    private

    def create_vault!
      raise Vault::Error, "Vault already exists: #{@path}" if File.exist?(@path)

      @db = new_database
      create_schema
    end

    def open_vault!
      raise Vault::NotFoundError, "Vault not found: #{@path}" unless File.exist?(@path)

      validate_sqlite!
      @db = new_database
      Vault.assert_readable!(format_version, @path)
      Deprecation.warn_once(deprecation_message)
    end

    def ensure_writable!
      return if @writable

      raise Vault::ReadOnlyError,
            "#{@path} uses the deprecated read-only SQLite format. Migrate it first: gemvault upgrade #{@path}"
    end

    def deprecation_message
      "SQLite vaults are deprecated and read-only; support will be removed in a future release (0.3-0.5). " \
        "Migrate #{@path} with: gemvault upgrade #{@path}"
    end

    def new_database
      db = SQLite3::Database.new(@path)
      db.results_as_hash = true
      db
    end

    def raise_if_duplicate(spec)
      existing = @db.execute(
        "SELECT 1 FROM gems WHERE name = ? AND version = ? AND platform = ?",
        [spec.name, spec.version.to_s, spec.platform.to_s],
      )
      return if existing.empty?

      raise Vault::DuplicateGemError,
            "Gem already in vault: #{spec.name}-#{spec.version} (#{spec.platform})"
    end

    def insert_gem(gem_path, spec, created_at)
      @db.execute(
        "INSERT INTO gems (name, version, platform, data, created_at) VALUES (?, ?, ?, ?, ?)",
        [spec.name, spec.version.to_s, spec.platform.to_s,
         SQLite3::Blob.new(File.binread(gem_path)), created_at],
      )
    end

    def timestamp
      Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")
    end

    def create_schema
      @db.execute_batch(<<~SQL)
        CREATE TABLE metadata (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );

        CREATE TABLE gems (
          name TEXT NOT NULL,
          version TEXT NOT NULL,
          platform TEXT NOT NULL DEFAULT 'ruby',
          data BLOB NOT NULL,
          created_at TEXT NOT NULL DEFAULT (datetime('now')),
          PRIMARY KEY (name, version, platform)
        );
      SQL

      @db.execute("INSERT INTO metadata (key, value) VALUES (?, ?)", ["vault_version", FORMAT_VERSION])
      @db.execute("INSERT INTO metadata (key, value) VALUES (?, ?)", ["created_at", timestamp])
    end

    def validate_sqlite!
      return if File.binread(@path, Vault::SQLITE_MAGIC.bytesize) == Vault::SQLITE_MAGIC

      raise Vault::Error, "Not a valid vault file (not SQLite): #{@path}"
    end
  end
end

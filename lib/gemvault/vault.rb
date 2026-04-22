require "sqlite3"
require "rubygems/package"
require "fileutils"
require "tempfile"
require_relative "gem_entry"
require_relative "gem_reference"

module Gemvault
  class Vault
    class Error < StandardError; end
    class NotFoundError < Error; end
    class DuplicateGemError < Error; end
    class InvalidGemError < Error; end

    SCHEMA_VERSION = "1".freeze

    attr_reader :path

    def self.open(path, **opts, &block)
      raise ArgumentError, "#{name}.open requires a block" unless block

      vault = new(path, **opts)
      begin
        yield vault
      ensure
        vault.close
      end
    end

    def initialize(path, create: false)
      @path = File.expand_path(path)

      if create
        raise Error, "Vault already exists: #{@path}" if File.exist?(@path)

        @db = SQLite3::Database.new(@path)
        @db.results_as_hash = true
        create_schema
      else
        raise NotFoundError, "Vault not found: #{@path}" unless File.exist?(@path)

        validate_sqlite!
        @db = SQLite3::Database.new(@path)
        @db.results_as_hash = true
      end
    end

    def add(gem_path)
      gem_path = File.expand_path(gem_path)
      raise NotFoundError, "Gem file not found: #{gem_path}" unless File.file?(gem_path)

      begin
        pkg = Gem::Package.new(gem_path)
        spec = pkg.spec
      rescue StandardError => e
        raise InvalidGemError, "Invalid gem file #{gem_path}: #{e.message}"
      end

      name = spec.name
      version = spec.version.to_s
      platform = spec.platform.to_s

      existing = @db.execute(
        "SELECT 1 FROM gems WHERE name = ? AND version = ? AND platform = ?",
        [name, version, platform],
      )
      unless existing.empty?
        raise DuplicateGemError,
              "Gem already in vault: #{name}-#{version} (#{platform})"
      end

      data = File.binread(gem_path)
      @db.execute(
        "INSERT INTO gems (name, version, platform, data) VALUES (?, ?, ?, ?)",
        [name, version, platform, SQLite3::Blob.new(data)],
      )
    end

    def remove(reference)
      case reference
      in GemReference::AnyVersion(name:)
        @db.execute("DELETE FROM gems WHERE name = ?", [name])
      in GemReference::SpecificVersion(name:, version:)
        @db.execute(
          "DELETE FROM gems WHERE name = ? AND version = ?",
          [name, version.to_s],
        )
      end
      @db.changes
    end

    def gem_data(name, version, platform: "ruby")
      row = @db.execute(
        "SELECT data FROM gems WHERE name = ? AND version = ? AND platform = ?",
        [name, version, platform],
      ).first

      raise NotFoundError, "Gem not found: #{name}-#{version} (#{platform})" unless row

      row["data"]
    end

    def specs
      gem_entries.map { |entry| spec_from_blob(entry.name, entry.version, entry.platform) }
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

    def with_gem_file(name, version, platform: "ruby")
      data = gem_data(name, version, platform: platform)
      tmpfile = Tempfile.new(["vault_gem", ".gem"])
      begin
        tmpfile.binmode
        tmpfile.write(data)
        tmpfile.close
        yield tmpfile.path
      ensure
        tmpfile.close unless tmpfile.closed?
        tmpfile.unlink
      end
    end

    def spec_from_blob(name, version, platform = "ruby")
      with_gem_file(name, version, platform: platform) do |path|
        Gem::Package.new(path).spec
      end
    end

    private

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

      @db.execute(
        "INSERT INTO metadata (key, value) VALUES (?, ?)",
        ["vault_version", SCHEMA_VERSION],
      )
      @db.execute(
        "INSERT INTO metadata (key, value) VALUES (?, ?)",
        ["created_at", Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")],
      )
    end

    def validate_sqlite!
      magic = File.binread(@path, 16)
      return if magic == "SQLite format 3\x00"

      raise Error, "Not a valid vault file (not SQLite): #{@path}"
    end
  end
end

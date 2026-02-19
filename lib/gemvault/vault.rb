# frozen_string_literal: true

require "sqlite3"
require "rubygems/package"
require "fileutils"
require "tempfile"

module Gemvault
  class Vault
    class Error < StandardError; end
    class NotFoundError < Error; end
    class DuplicateGemError < Error; end
    class InvalidGemError < Error; end

    SCHEMA_VERSION = "1"

    attr_reader :path

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
      rescue => e
        raise InvalidGemError, "Invalid gem file #{gem_path}: #{e.message}"
      end

      name = spec.name
      version = spec.version.to_s
      platform = spec.platform.to_s

      existing = @db.execute(
        "SELECT 1 FROM gems WHERE name = ? AND version = ? AND platform = ?",
        [name, version, platform]
      )
      unless existing.empty?
        raise DuplicateGemError,
          "Gem already in vault: #{name}-#{version} (#{platform})"
      end

      data = File.binread(gem_path)
      @db.execute(
        "INSERT INTO gems (name, version, platform, spec, data) VALUES (?, ?, ?, ?, ?)",
        [name, version, platform, spec.to_ruby, SQLite3::Blob.new(data)]
      )
    end

    def list
      @db.execute(
        "SELECT name, version, platform, created_at FROM gems ORDER BY name, version"
      )
    end

    def remove(name, version = nil)
      if version
        @db.execute(
          "DELETE FROM gems WHERE name = ? AND version = ?",
          [name, version]
        )
      else
        @db.execute(
          "DELETE FROM gems WHERE name = ?",
          [name]
        )
      end
      @db.changes
    end

    def gem_data(name, version, platform: "ruby")
      row = @db.execute(
        "SELECT data FROM gems WHERE name = ? AND version = ? AND platform = ?",
        [name, version, platform]
      ).first

      raise NotFoundError, "Gem not found: #{name}-#{version} (#{platform})" unless row
      row["data"]
    end

    def gem_spec_ruby(name, version, platform: "ruby")
      row = @db.execute(
        "SELECT spec FROM gems WHERE name = ? AND version = ? AND platform = ?",
        [name, version, platform]
      ).first

      raise NotFoundError, "Gem not found: #{name}-#{version} (#{platform})" unless row
      row["spec"]
    end

    def specs
      rows = @db.execute("SELECT name, version, platform FROM gems")
      rows.map { |row| spec_from_blob(row["name"], row["version"], row["platform"]) }
    end

    def gem_entries
      @db.execute(
        "SELECT name, version, platform, spec, created_at FROM gems ORDER BY name, version"
      )
    end

    def size
      @db.execute("SELECT COUNT(*) AS count FROM gems").first["count"]
    end

    def close
      @db.close if @db && !@db.closed?
    end

    def spec_from_blob(name, version, platform = "ruby")
      data = gem_data(name, version, platform: platform)
      tmpfile = Tempfile.new(["vault_spec", ".gem"])
      begin
        tmpfile.binmode
        tmpfile.write(data)
        tmpfile.close
        Gem::Package.new(tmpfile.path).spec
      ensure
        tmpfile.unlink
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
          spec TEXT NOT NULL,
          data BLOB NOT NULL,
          created_at TEXT NOT NULL DEFAULT (datetime('now')),
          PRIMARY KEY (name, version, platform)
        );
      SQL

      @db.execute(
        "INSERT INTO metadata (key, value) VALUES (?, ?)",
        ["vault_version", SCHEMA_VERSION]
      )
      @db.execute(
        "INSERT INTO metadata (key, value) VALUES (?, ?)",
        ["created_at", Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")]
      )
    end

    def validate_sqlite!
      magic = File.binread(@path, 16)
      return if magic == "SQLite format 3\x00"
      raise Error, "Not a valid vault file (not SQLite): #{@path}"
    end
  end
end

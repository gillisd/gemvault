require_relative "database"
require "rubygems/package"
require "fileutils"
require "tempfile"
require_relative "gem_entry"
require_relative "gem_reference"

module Gemvault
  # SQLite-backed archive of .gem blobs; supports add/remove/list/extract.
  class Vault
    class Error < StandardError; end
    class NotFoundError < Error; end
    class DuplicateGemError < Error; end
    class InvalidGemError < Error; end

    SCHEMA_VERSION = "1".freeze
    SQLITE_MAGIC = "SQLite format 3#{0.chr}".freeze

    CREATE_METADATA_TABLE_SQL = <<~SQL.freeze
      CREATE TABLE metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    SQL

    CREATE_GEMS_TABLE_SQL = <<~SQL.freeze
      CREATE TABLE gems (
        name TEXT NOT NULL,
        version TEXT NOT NULL,
        platform TEXT NOT NULL DEFAULT 'ruby',
        data BLOB NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        PRIMARY KEY (name, version, platform)
      )
    SQL

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
      create ? create_vault! : open_vault!
    end

    def add(gem_path)
      gem_path = File.expand_path(gem_path)
      raise NotFoundError, "Gem file not found: #{gem_path}" unless File.file?(gem_path)

      spec = load_gem_spec(gem_path)
      raise_if_duplicate(spec)
      insert_gem(gem_path, spec)
    end

    def remove(reference)
      case reference
      in GemReference::AnyVersion[name:]
        db[:gems].where(name: name).delete
      in GemReference::SpecificVersion[name:, version:]
        db[:gems].where(name: name, version: version.to_s).delete
      end
    end

    def gem_data(name, version, platform: "ruby")
      row = db[:gems].where(name: name, version: version, platform: platform).select(:data).first
      raise NotFoundError, "Gem not found: #{name}-#{version} (#{platform})" unless row

      row[:data]
    end

    def specs
      gem_entries.map { |entry| spec_from_blob(entry.name, entry.version, entry.platform) }
    end

    def gem_entries
      db[:gems]
        .select(:name, :version, :platform, :created_at)
        .order(:name, :version)
        .map { |row| GemEntry.new(**row) }
    end

    def size
      db[:gems].count
    end

    def close
      return unless @db

      @db.disconnect
      @db = nil
    end

    def with_gem_file(name, version, platform: "ruby")
      data = gem_data(name, version, platform: platform)
      tmpfile = write_tempfile(data)
      begin
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

    def db
      @db || raise(ArgumentError, "vault is closed")
    end

    def create_vault!
      raise Error, "Vault already exists: #{@path}" if File.exist?(@path)

      @db = Gemvault::Database.connect(@path)
      create_schema
    end

    def open_vault!
      raise NotFoundError, "Vault not found: #{@path}" unless File.exist?(@path)

      validate_sqlite!
      @db = Gemvault::Database.connect(@path)
    end

    def load_gem_spec(gem_path)
      Gem::Package.new(gem_path).spec
    rescue StandardError => e
      raise InvalidGemError, "Invalid gem file #{gem_path}: #{e.message}"
    end

    def raise_if_duplicate(spec)
      existing = db[:gems].where(
        name: spec.name,
        version: spec.version.to_s,
        platform: spec.platform.to_s,
      )
      return if existing.empty?

      raise DuplicateGemError,
            "Gem already in vault: #{spec.name}-#{spec.version} (#{spec.platform})"
    end

    def insert_gem(gem_path, spec)
      db[:gems].insert(
        name: spec.name,
        version: spec.version.to_s,
        platform: spec.platform.to_s,
        data: Sequel.blob(File.binread(gem_path)),
      )
    end

    def write_tempfile(data)
      tmpfile = Tempfile.new(["vault_gem", ".gem"])
      tmpfile.binmode
      tmpfile.write(data)
      tmpfile.close
      tmpfile
    end

    def create_schema
      db.run(CREATE_METADATA_TABLE_SQL)
      db.run(CREATE_GEMS_TABLE_SQL)
      insert_metadata("vault_version", SCHEMA_VERSION)
      insert_metadata("created_at", Time.now.utc.strftime("%Y-%m-%d %H:%M:%S"))
    end

    def insert_metadata(key, value)
      db[:metadata].insert(key: key, value: value)
    end

    def validate_sqlite!
      return if File.binread(@path, SQLITE_MAGIC.bytesize) == SQLITE_MAGIC

      raise Error, "Not a valid vault file (not SQLite): #{@path}"
    end
  end
end

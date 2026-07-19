require "time"
require "pathname"
require_relative "vault"
require_relative "vault_session"
require_relative "gem_extraction"
require_relative "manifest"
require_relative "tarball"
require_relative "archive_entry"
require_relative "gem_entry"
require_relative "gem_reference"

module Gemvault
  # A Tarvault: a tarball whose first entry is manifest.json and whose
  # remaining entries are .gem files. Portable, dependency-free storage.
  class Tarvault
    extend VaultSession
    include GemExtraction

    attr_reader :path

    def initialize(path, create: false)
      @path = Pathname(path).expand_path
      @archive = Tarball.new(@path)
      @closed = false
      create ? create_vault! : load_manifest!
    end

    def add(gem_path, created_at: nil)
      gem_path = Pathname(gem_path).expand_path
      raise Vault::NotFoundError, "Gem file not found: #{gem_path}" unless gem_path.file?

      spec = spec_from_gem_file(gem_path)
      entry = GemEntry.from_spec(spec, created_at: created_at || timestamp)
      raise_if_duplicate(entry)
      store(entry:, bytes: gem_path.binread)
    end

    def remove(reference)
      dropped = @manifest.matching(reference)
      return 0 if dropped.empty?

      @manifest = @manifest.without(dropped)
      remaining = survivors_excluding(dropped)
      rewrite(remaining)
      dropped.size
    end

    def gem_data(entry)
      record = @manifest.find(entry)
      raise Vault::NotFoundError, "Gem not found: #{entry}" unless record

      bytes = @archive.read(record.filename)
      raise Vault::Error, "Integrity check failed for #{record.filename}" unless record.matches?(bytes)

      bytes
    end

    def gem_entries
      @manifest.gem_entries
    end

    def format_version
      @manifest.format_version
    end

    def size
      @manifest.size
    end

    def close
      @closed = true
    end

    def closed?
      @closed
    end

    private

    def create_vault!
      raise Vault::Error, "Vault already exists: #{@path}" if @path.exist?

      @manifest = Manifest.empty(created_at: timestamp)
      rewrite([])
    end

    def load_manifest!
      begin
        raise Vault::NotFoundError, "Vault not found: #{@path}" unless @path.exist?

        @manifest = Manifest.parse(read_manifest_json)
        Vault.assert_readable!(version: @manifest.format_version, path: @path)
      rescue JSON::ParserError, Gem::Package::TarInvalidError, ArgumentError, Errno::EINVAL
        raise Vault::Error, "Not a valid Tarvault: #{@path}"
      end
    end

    def read_manifest_json
      json = @archive.read(Manifest::FILENAME)
      raise Vault::Error, "Not a valid Tarvault (missing manifest): #{@path}" unless json

      json
    end

    def store(entry:, bytes:)
      record = build_record(entry:, bytes:)
      @manifest = @manifest.with_record(record)
      rewrite(survivors + [ArchiveEntry.new(name: record.filename, bytes:)])
    end

    def rewrite(gems)
      manifest_entry = ArchiveEntry.new(name: Manifest::FILENAME, bytes: @manifest.to_json)
      @archive.write([manifest_entry] + gems)
    end

    def survivors
      @archive.entries.reject { |entry| entry.name == Manifest::FILENAME }
    end

    def survivors_excluding(dropped)
      names = dropped.map(&:filename)
      survivors.reject { |entry| names.include?(entry.name) }
    end

    def build_record(entry:, bytes:)
      Manifest::StoredGem.new(gem: entry, sha256: Manifest.digest(bytes), encrypted: false)
    end

    def raise_if_duplicate(entry)
      return unless @manifest.find(entry)

      raise Vault::DuplicateGemError, "Gem already in vault: #{entry}"
    end

    def timestamp
      Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")
    end
  end
end

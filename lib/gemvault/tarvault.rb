require "time"
require "json"
require_relative "vault"
require_relative "vault_session"
require_relative "gem_extraction"
require_relative "manifest"
require_relative "tar_archive"
require_relative "gem_reference"

module Gemvault
  # A Tarvault: a tarball whose first entry is manifest.json and whose
  # remaining entries are .gem files. Portable, dependency-free storage.
  class Tarvault
    extend VaultSession
    include GemExtraction

    attr_reader :path

    def initialize(path, create: false)
      @path = File.expand_path(path)
      @archive = TarArchive.new(@path)
      @closed = false
      create ? create_vault! : load_manifest!
    end

    def add(gem_path)
      gem_path = File.expand_path(gem_path)
      raise Vault::NotFoundError, "Gem file not found: #{gem_path}" unless File.file?(gem_path)

      spec = load_spec(gem_path)
      raise_if_duplicate(spec)
      store(spec, File.binread(gem_path))
    end

    def remove(reference)
      dropped = matching_records(reference)
      return 0 if dropped.empty?

      @manifest = @manifest.without(dropped)
      rewrite(survivors_excluding(dropped))
      dropped.size
    end

    def gem_data(name, version, platform: "ruby")
      record = @manifest.find(name, version, platform)
      raise Vault::NotFoundError, "Gem not found: #{name}-#{version} (#{platform})" unless record

      verify(@archive.read(record.filename), record)
    end

    def gem_entries
      @manifest.gem_entries
    end

    def specs
      gem_entries.map { |e| spec_from_blob(e.name, e.version, e.platform) }
    end

    def size
      @manifest.records.size
    end

    def close
      @closed = true
    end

    def closed?
      @closed
    end

    private

    def create_vault!
      raise Vault::Error, "Vault already exists: #{@path}" if File.exist?(@path)

      @manifest = Manifest.empty(created_at: timestamp)
      rewrite([])
    end

    def load_manifest!
      raise Vault::NotFoundError, "Vault not found: #{@path}" unless File.exist?(@path)

      @manifest = Manifest.parse(read_manifest_json)
    rescue JSON::ParserError, Gem::Package::TarInvalidError, ArgumentError, Errno::EINVAL
      raise Vault::Error, "Not a valid Tarvault: #{@path}"
    end

    def read_manifest_json
      json = @archive.read(Manifest::FILENAME)
      raise Vault::Error, "Not a valid Tarvault (missing manifest): #{@path}" unless json

      json
    end

    def store(spec, bytes)
      record = build_record(spec, bytes)
      @manifest = @manifest.with(record)
      rewrite(@archive.gem_pairs + [[record.filename, bytes]])
    end

    def rewrite(gem_pairs)
      @archive.write([[Manifest::FILENAME, @manifest.to_json]] + gem_pairs)
    end

    def survivors_excluding(dropped)
      names = dropped.map(&:filename)
      @archive.gem_pairs.reject { |pair| names.include?(pair.first) }
    end

    def build_record(spec, bytes)
      Manifest::Record.new(
        name: spec.name,
        version: spec.version.to_s,
        platform: spec.platform.to_s,
        created_at: timestamp,
        sha256: Manifest.digest(bytes),
        encrypted: false,
      )
    end

    def matching_records(reference)
      case reference
      in GemReference::AnyVersion[name:]
        @manifest.records.select { |r| r.name == name }
      in GemReference::SpecificVersion[name:, version:]
        @manifest.records.select { |r| r.name == name && r.version == version.to_s }
      end
    end

    def raise_if_duplicate(spec)
      return unless @manifest.find(spec.name, spec.version.to_s, spec.platform.to_s)

      raise Vault::DuplicateGemError,
            "Gem already in vault: #{spec.name}-#{spec.version} (#{spec.platform})"
    end

    def verify(bytes, record)
      return bytes if Manifest.digest(bytes) == record.sha256

      raise Vault::Error, "Integrity check failed for #{record.filename}"
    end

    def load_spec(gem_path)
      Gem::Package.new(gem_path).spec
    rescue StandardError => e
      raise Vault::InvalidGemError, "Invalid gem file #{gem_path}: #{e.message}"
    end

    def timestamp
      Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")
    end
  end
end

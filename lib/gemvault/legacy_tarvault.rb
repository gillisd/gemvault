require "pathname"
require_relative "vault"
require_relative "vault_session"
require_relative "gem_extraction"
require_relative "gem_entry"
require_relative "manifest_text"
require_relative "tarball"
require_relative "timestamp"
require_relative "deprecation"

module Gemvault
  ##
  # Read-only reader for a format-2 vault: a tarball whose index is the
  # manifest.json gemvault wrote through 0.2.x. It exists so +gemvault upgrade+
  # migrates such a vault through the same pipeline every other format takes,
  # rather than leaving the gems stranded behind an error.
  #
  # It does not read that manifest. The index is derived from the payload
  # instead: each stored .gem carries its own gemspec, which is where the
  # manifest's identity fields came from in the first place. That keeps the
  # old notation from re-entering the codebase to be parsed (issue #25) and
  # makes the reader indifferent to a manifest that is damaged or missing.
  #
  # Two things the old index held are consequently gone. Each gem's stored
  # time is unrecoverable, so entries are stamped when the vault is opened;
  # and the per-gem digests cannot be checked, so a migrated gem is trusted as
  # the bytes found in the archive -- the new vault records fresh digests of
  # exactly what it copied.
  class LegacyTarvault
    extend VaultSession
    include GemExtraction

    FORMAT_VERSION = 2

    attr_reader :path

    def initialize(path)
      @path = Pathname(path).expand_path
      @archive = Tarball.new(@path)
      @closed = false
      open_vault!
    end

    def add(*)
      raise Vault::ReadOnlyError, read_only_message
    end

    def remove(*)
      raise Vault::ReadOnlyError, read_only_message
    end

    def gem_data(entry)
      bytes = @archive.read(entry.filename)
      raise Vault::NotFoundError, "Gem not found: #{entry}" unless bytes

      bytes
    end

    def gem_entries
      @gem_entries ||= derived_entries
    end

    def format_version = FORMAT_VERSION

    def size = gem_members.size

    def close
      @closed = true
    end

    def closed? = @closed

    private

    def open_vault!
      raise Vault::NotFoundError, "Vault not found: #{@path}" unless @path.exist?

      @opened_at = Timestamp.now
      Deprecation.warn_once(deprecation_message)
    end

    # Deriving the index means reading the archive and every gem in it, so it
    # meets the same wreckage Tarvault's open path does and owes the user the
    # same answer: the vault named, not a tar library's error.
    def derived_entries
      gem_members.map { |member| entry_for(member) }.sort_by { |gem| [gem.name, gem.version] }
    rescue Gem::Package::Error, ArgumentError, Errno::EINVAL
      raise Vault::Error, "Not a valid Tarvault: #{@path}"
    end

    def gem_members
      @archive.entries.reject { |member| member.name == ManifestText::LEGACY_FILENAME }
    end

    def entry_for(member)
      GemEntry.from_spec(Gem::Package.new(StringIO.new(member.bytes)).spec, created_at: @opened_at)
    end

    def read_only_message
      "Vault #{@path} is format #{FORMAT_VERSION} and read-only. Migrate it with: gemvault upgrade #{@path}"
    end

    def deprecation_message
      "format #{FORMAT_VERSION} vaults are read-only, and their stored times cannot be recovered. " \
        "Migrate #{@path} with: gemvault upgrade #{@path}"
    end
  end
end

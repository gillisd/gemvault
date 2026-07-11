require "fileutils"
require_relative "vault"

module Gemvault
  # Migrates a vault to the current storage format by reading it through its
  # existing backend and rewriting it through the current-format writer, then
  # atomically swapping the file into place. Preserves each gem's created_at.
  class VaultUpgrade
    # The from/to/gem-count summary of an upgrade; also detects an
    # already-current (no-op) vault.
    Plan = Struct.new(:from_version, :to_version, :gem_count, keyword_init: true) do
      def no_op?
        from_version == to_version
      end

      def to_s
        "format #{from_version} -> #{to_version}"
      end
    end

    def initialize(path, backup: true)
      @path = File.expand_path(path)
      @backup = backup
    end

    def plan
      Vault.open(@path) do |vault|
        Plan.new(from_version: vault.format_version, to_version: Vault::CURRENT_FORMAT, gem_count: vault.size)
      end
    end

    def call
      summary = plan
      return summary if summary.no_op?

      backup! if @backup
      rebuild(summary.gem_count)
      summary
    end

    private

    def backup!
      backup_path = "#{@path}.bak"
      if File.exist?(backup_path)
        raise Vault::Error, "Backup already exists: #{backup_path} (remove it or pass --no-backup)"
      end

      FileUtils.cp(@path, backup_path)
    end

    def rebuild(expected_count)
      tmp = "#{@path}.upgrading"
      FileUtils.rm_f(tmp)
      copy_current_format(tmp)
      verify_count!(tmp, expected_count)
      File.rename(tmp, @path)
    end

    def copy_current_format(tmp)
      Vault.open(@path) do |old|
        target = Vault.new(tmp, create: true)
        old.gem_entries.each { |entry| copy_gem(old, target, entry) }
        target.close
      end
    end

    def copy_gem(old, target, entry)
      old.with_gem_file(entry.name, entry.version, platform: entry.platform) do |gem_path|
        target.add(gem_path, created_at: entry.created_at)
      end
    end

    def verify_count!(tmp, expected_count)
      actual = Vault.open(tmp, &:size)
      return if actual == expected_count

      FileUtils.rm_f(tmp)
      raise Vault::Error, "Upgrade verification failed: expected #{expected_count} gems, got #{actual}"
    end
  end
end

require "pathname"
require "fileutils"
require_relative "vault"
require_relative "deprecation"

module Gemvault
  # Migrates a vault to the current storage format by reading it through its
  # existing backend and rewriting it through the current-format writer, then
  # atomically swapping the file into place. Preserves each gem's created_at.
  class VaultUpgrade
    include FileUtils

    # The from/to/gem-count summary of an upgrade; also detects an
    # already-current (no-op) vault.
    class Plan < Data.define(:from_version, :to_version, :gem_count)
      def no_op? = from_version == to_version

      def to_s = "format #{from_version} -> #{to_version} (#{gem_count} gems)"

      def deconstruct_keys(_keys)
        { from_version:, to_version:, gem_count:, no_op: no_op? }
      end
    end

    # Copies gems from a source vault into a target vault, preserving each
    # gem's stored timestamp. Holds the two endpoints so the per-gem call
    # takes only the entry.
    class GemCopy < Data.define(:source, :target)
      def call(entry)
        source.with_gem_file(entry) do |gem_path|
          target.add(gem_path, created_at: entry.created_at)
        end
      end
    end

    def initialize(path, backup: true)
      @path = Pathname(path).expand_path
      @backup = backup
    end

    def plan
      Deprecation.silence do
        Vault.open(@path) do |vault|
          Plan.new(from_version: vault.format_version, to_version: Vault::CURRENT_FORMAT, gem_count: vault.size)
        end
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
      backup_path = Pathname("#{@path}.bak")
      raise Vault::Error, "Backup already exists: #{backup_path} (remove it or pass --no-backup)" if backup_path.exist?

      cp(@path, backup_path)
    end

    def rebuild(expected_count)
      tmp = Pathname("#{@path}.upgrading")
      rm_f(tmp)
      copy_current_format(tmp)
      verify_count!(tmp:, expected_count:)
      tmp.rename(@path)
    end

    def copy_current_format(tmp)
      Deprecation.silence do
        Vault.open(@path) do |old|
          target = Vault.new(tmp, create: true)
          copy = GemCopy.new(source: old, target:)
          old.gem_entries.each { |entry| copy.call(entry) }
          target.close
        end
      end
    end

    def verify_count!(tmp:, expected_count:)
      actual = Vault.open(tmp, &:size)
      return if actual == expected_count

      rm_f(tmp)
      raise Vault::Error, "Upgrade verification failed: expected #{expected_count} gems, got #{actual}"
    end
  end
end

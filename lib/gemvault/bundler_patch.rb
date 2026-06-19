require "open3"

require_relative "bundler_patch/outcome"
require_relative "bundler_patch/outcomes"

module Gemvault
  # The fix for Bundler's plugin-reinstall bug
  # (rubygems/rubygems#6630, rubygems/rubygems#6957). Ships as a unified
  # diff next to this file; applied via the canonical `patch` tool so the
  # actual file surgery, hunk matching, and reversal are handled by
  # battle-tested upstream utilities. Idempotency is checked in Ruby with
  # a marker comment because `patch` cannot natively distinguish a pure
  # insertion that's already been applied from a pristine target.
  class BundlerPatch
    DEFAULT_DIFF = Pathname(__dir__).join("bundler_patch.diff").freeze
    MARKER = "# gemvault-bundler-patch: skip-reinstalled-plugins".freeze

    attr_reader :diff

    def initialize(diff: DEFAULT_DIFF, runner: Open3.method(:capture2e))
      @diff = Pathname(diff)
      @runner = runner
    end

    def apply_to(installation)
      return Outcome::AlreadyApplied[installation: installation] if marker_present?(installation)

      run_patch(installation, "--forward")
      Outcome::Applied[installation: installation]
    end

    def revert_from(installation)
      return Outcome::NotApplied[installation: installation] unless marker_present?(installation)

      run_patch(installation, "--reverse")
      Outcome::Reverted[installation: installation]
    end

    class PatchFailed < StandardError; end

    private

    attr_reader :runner

    def marker_present?(installation)
      installation.plugin_rb.read.include?(MARKER)
    end

    def run_patch(installation, direction)
      _, status = runner.call(
        "patch", direction, "--silent", "--no-backup-if-mismatch",
        "--reject-file=-", installation.plugin_rb.to_s, diff.to_s
      )
      return if status.success?

      raise PatchFailed, "patch #{direction} failed on #{installation}"
    end
  end
end

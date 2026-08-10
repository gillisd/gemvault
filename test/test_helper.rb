require "minitest/reporters"
require "minitest/autorun"
require "fileutils"
require "gemvault"
require "tmpdir"
require "open3"
require_relative "support/gem_factory"

Minitest::Reporters.use!

# Shared helpers mixed into the gemvault test cases.
module GemvaultTestHelper
  # Build a real .gem file programmatically.
  #
  # @param name [String] gem name
  # @param version [String] gem version
  # @param options [Hash] forwarded to GemFactory (dir:, platform:, files:, dependencies:)
  # @return [Pathname] absolute path to the built .gem file
  def build_gem(name:, version:, **options)
    GemFactory.new(name: name, version: version, **options).build
  end

  def gem_entry(name:, version:)
    Gemvault::GemEntry.new(name: name, version: version)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if @tmpdir
    super
  end

  # Standard on-disk layout for vault tests: a private tmpdir holding a gem
  # build area and the vault-to-be.
  def vault_workspace(prefix)
    @tmpdir = Pathname(Dir.mktmpdir(prefix))
    @gem_build_dir = @tmpdir / "gems"
    @gem_build_dir.mkpath
    @vault_path = @tmpdir / "test.gemv"
  end

  # Same-named gems collide on their fixture files, so each extra version
  # builds in its own subdirectory.
  def build_subdir_gem(name:, version:, subdir:, **options)
    dir = @gem_build_dir / subdir
    dir.mkpath
    build_gem(name: name, version: version, dir: dir, **options)
  end

  def populate_vault(path:, gem_paths:)
    vault = Gemvault::Vault.new(path, create: true)
    gem_paths.each { |gem_path| vault.add(gem_path) }
    vault.close
  end
end

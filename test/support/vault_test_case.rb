class VaultTestCase < Minitest::Test
  include GemvaultTestHelper

  def setup
    vault_workspace("gemvault_test")
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  private

  def create_vault
    Gemvault::Vault.new(@vault_path, create: true)
  end

  def specific_version_ref(name:, version:)
    Gemvault::GemReference::SpecificVersion.new(
      name: name, version: Gem::Version.new(version),
    )
  end

  def vault_containing(*gem_paths)
    vault = create_vault
    gem_paths.each { |gem_path| vault.add(gem_path) }
    vault
  end

  def foo_gem
    build_gem(name: "foo", version: "1.0.0", dir: @gem_build_dir)
  end
end

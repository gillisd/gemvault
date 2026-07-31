class RubygemsSourceVaultCase < Minitest::Test
  include GemvaultTestHelper

  ALPHA_FILES = { "lib/alpha.rb" => "module Alpha; end" }.freeze
  BETA_FILES = { "lib/beta.rb" => "module Beta; end" }.freeze

  def setup
    vault_workspace("gemvault_rubygems_test")
    build_fixture_vault
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  private

  def build_fixture_vault
    @gem1_path = build_gem(name: "alpha", version: "1.0.0", dir: @gem_build_dir, files: ALPHA_FILES)
    @gem2_path = build_subdir_gem(name: "alpha", version: "2.0.0", subdir: "gem2", files: ALPHA_FILES)
    @gem3_path = build_subdir_gem(name: "beta", version: "1.0.0", subdir: "gem3", files: BETA_FILES)
    @gem_pre_path = build_subdir_gem(name: "beta", version: "2.0.0.pre1", subdir: "gem4", files: BETA_FILES)
    populate_vault(path: @vault_path, gem_paths: [@gem1_path, @gem2_path, @gem3_path, @gem_pre_path])
  end

  def name_tuple(name, version)
    Gem::NameTuple.new(name, Gem::Version.new(version), "ruby")
  end

  def add_native_alpha_to_vault
    platform_gem = build_subdir_gem(name: "alpha", version: "2.0.0", subdir: "gem_native", platform: "x86_64-linux")
    vault = Gemvault::Vault.new(@vault_path)
    vault.add(platform_gem)
    vault.close
  end
end

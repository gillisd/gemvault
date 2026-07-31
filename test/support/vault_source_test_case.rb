require "bundler"
require "bundler/plugin/api"
require "bundler/plugin/vault_source"

Bundler::Plugin::VaultSource.include(Bundler::Plugin::API::Source)

class VaultSourceTestCase < Minitest::Test
  include GemvaultTestHelper

  def setup
    vault_workspace("vault_source_test")
    build_fixture_vault
  end

  private

  def build_fixture_vault
    @gem1_path = build_gem(name: "alpha", version: "1.0.0", dir: @gem_build_dir,
                           files: { "lib/alpha.rb" => 'module Alpha; VERSION = "1.0.0"; end' })
    @gem2_path = build_subdir_gem(name: "beta", version: "2.0.0", subdir: "beta_dir",
                                  files: { "lib/beta.rb" => 'module Beta; VERSION = "2.0.0"; end' })
    populate_vault(path: @vault_path, gem_paths: [@gem1_path, @gem2_path])
  end

  def vault_source_with_gem(name:, version:, subdir:, remote: true, **options)
    gem_path = build_subdir_gem(name: name, version: version, subdir: subdir, **options)
    vault_path = @tmpdir / "#{name}.gemv"
    populate_vault(path: vault_path, gem_paths: [gem_path])
    create_vault_source(vault_path, remote: remote)
  end

  def find_spec(source:, name:)
    source.specs.to_a.find { |s| s.name == name }
  end

  def create_vault_source(path, dependency_names: [], remote: true)
    opts = { "uri" => path.to_s, "type" => "vault" }
    source = Bundler::Plugin::VaultSource.new(opts)
    source.dependency_names = dependency_names
    source.remote! if remote
    source
  end
end

require "test_helper"
require_relative "support/vault_source_test_case"

class VaultSourceGemspecTest < VaultSourceTestCase
  def test_fetch_gemspec_files_returns_all_gems
    source = create_vault_source(@vault_path)
    files = source.fetch_gemspec_files

    assert_equal 2, files.length
    files.each { |f| assert_path_exists f }
  end

  def test_fetch_gemspec_files_returns_valid_gemspecs
    source = create_vault_source(@vault_path)
    files = source.fetch_gemspec_files
    specs = files.map { |f| Gem::Specification.load(f) }
    names = specs.map(&:name).sort

    assert_equal %w[alpha beta], names
  end

  def test_specs_returns_searchable_index
    source = create_vault_source(@vault_path)
    source.dependency_names = %w[alpha beta]
    specs_list = source.specs.to_a
    names = specs_list.map(&:name).sort

    assert_equal %w[alpha beta], names
  end

  def test_platform_gem
    source = vault_source_with_gem(name: "native", version: "1.0.0", subdir: "native_dir", platform: "x86_64-linux")
    files = source.fetch_gemspec_files

    assert_equal 1, files.length
    spec = Gem::Specification.load(files.first)

    assert_equal "x86_64-linux", spec.platform.to_s
  end

  def test_dependencies_preserved
    source = vault_source_with_gem(name: "depgem", version: "1.0.0", subdir: "dep_dir",
                                   dependencies: [["rake", ">= 13.0"]])
    files = source.fetch_gemspec_files
    spec = Gem::Specification.load(files.first)
    dep = spec.dependencies.find { |d| d.name == "rake" }

    refute_nil dep
    assert_equal Gem::Requirement.new(">= 13.0"), dep.requirement
  end
end

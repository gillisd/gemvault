RSpec.describe "bundle install with vault source", :integration do
  it "installs a gem and makes it loadable" do
    expect(install_and_require_single_gem).to succeed_showing("1.0.0")
  end

  it "installs multiple gems from one vault" do
    expect(install_multiple_gems)
      .to succeed_showing("alpha_vault (1.0.0)", "beta_vault (2.0.0)", "gamma_vault (3.0.0)")
  end

  it "writes a correct lockfile" do
    expect(install_and_print_lockfile).to succeed_showing("PLUGIN SOURCE", "type: vault", "vault_test_gem (1.0.0)")
  end

  it "produces an idempotent lockfile" do
    expect(install_twice_and_diff_lockfile).to succeed
  end

  it "works alongside a rubygems source" do
    expect(install_alongside_rubygems_source).to succeed_showing("Bundle complete!")
  end

  it "installs only requested gems from a vault" do
    expect(install_only_requested_gems).to succeed
  end

  it "resolves intra-vault dependencies" do
    expect(install_intra_vault_dependencies).to succeed_showing("depa (1.0.0)", "depb (1.0.0)")
  end

  it "picks the correct version with a constraint" do
    expect(install_constrained_version).to succeed_showing("multiver (2.0.0)").without("multiver (1.0.0)")
  end

  context "when a version constraint cannot be satisfied" do
    it "fails with a meaningful error" do
      output, = install_unsatisfiable_constraint
      expect(output).to match(/could not find/i)
    end
  end

  context "when the user runs bundle cache with path: vendor" do
    it "succeeds" do
      expect(cache_to_vendor).to succeed
    end
  end

  context "when a path-installed bundler plugin's source directory has been renamed" do
    let(:outcome) { plugin_path_rename_outcome }

    it "crashes until `gemvault doctor` clears the index and reinstalls the plugin", :aggregate_failures do
      expect(outcome.broken).to match(PluginPathRenameScenario::BROKEN_PLUGIN_PATH_ERROR)
      expect(outcome.healed).to include("Bundle complete!")
    end
  end

  context "when the .gemv file is renamed and the Gemfile updated to match" do
    it "reinstalls against the new path without crashing on the stale lockfile entry" do
      expect(install_after_vault_rename).to succeed.without("Could not find vault")
    end
  end

  context "when the Gemfile references the vault by a relative path" do
    it "logs the relative path as written, not the basename" do
      expect(install_with_relative_vault_path).to succeed_showing("from vault vendor/vendored.gemv")
    end
  end
end

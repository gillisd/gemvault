BROKEN_PLUGIN_PATH_ERROR = /path .* does not exist|plugin paths don't exist|undefined method.*'new' for nil/i

RSpec.describe "bundle install with vault source", :integration do
  it "installs a gem and makes it loadable", :aggregate_failures do
    output, status = install_and_require_single_gem
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("1.0.0")
  end

  it "installs multiple gems from one vault", :aggregate_failures do
    output, status = install_multiple_gems
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("alpha_vault (1.0.0)")
    expect(output).to include("beta_vault (2.0.0)")
    expect(output).to include("gamma_vault (3.0.0)")
  end

  it "writes a correct lockfile", :aggregate_failures do
    output, status = install_and_print_lockfile
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("PLUGIN SOURCE")
    expect(output).to include("type: vault")
    expect(output).to include("vault_test_gem (1.0.0)")
  end

  it "produces an idempotent lockfile" do
    output, status = install_twice_and_diff_lockfile
    expect(status).to be_success, "Lockfile changed after second install:\n#{output}"
  end

  it "works alongside a rubygems.org source", :aggregate_failures do
    output, status = install_alongside_rubygems_source
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("Bundle complete!")
  end

  it "installs only requested gems from a vault" do
    output, status = install_only_requested_gems
    expect(status).to be_success, "Failed:\n#{output}"
  end

  it "resolves intra-vault dependencies", :aggregate_failures do
    output, status = install_intra_vault_dependencies
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("depa (1.0.0)")
    expect(output).to include("depb (1.0.0)")
  end

  it "picks the correct version with a constraint", :aggregate_failures do
    output, status = install_constrained_version
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("multiver (2.0.0)")
    expect(output).not_to include("multiver (1.0.0)")
  end

  context "when a version constraint cannot be satisfied" do
    it "fails with a meaningful error" do
      output, = install_unsatisfiable_constraint
      expect(output).to match(/could not find/i)
    end
  end

  context "when the user runs bundle cache with path: vendor" do
    it "succeeds" do
      output, status = cache_to_vendor
      expect(status).to be_success, "bundle cache failed:\n#{output}"
    end
  end

  context "when a path-installed bundler plugin's source directory has been renamed" do
    let(:rename_repro_script) do
      <<~SH
        #{FixtureScript.preamble(gems: [["path_change_gem", "1.0.0"]])}
        set +e
        mkdir -p /tmp/shim-a
        cat > /tmp/shim-a/bundler-source-vault.gemspec <<'GEMSPEC'
        Gem::Specification.new do |s|
          s.name = "bundler-source-vault"
          s.version = "99.0.0"
          s.summary = "test shim"
          s.authors = ["t"]
          s.files = ["plugins.rb"]
          s.require_paths = ["."]
          s.add_dependency "gemvault"
        end
        GEMSPEC
        cat > /tmp/shim-a/plugins.rb <<'PLUGINSRB'
        require "bundler/plugin/vault_source"
        Bundler::Plugin::API.source("vault", Bundler::Plugin::VaultSource)
        PLUGINSRB

        cd $WORKDIR
        cat > Gemfile <<GEMFILE
        source "https://rubygems.org"
        plugin "bundler-source-vault", path: "/tmp/shim-a"
        source "$WORKDIR/test.gemv", type: :vault do
          gem "path_change_gem"
        end
        GEMFILE
        bundle install 2>&1
        echo "===INITIAL_INSTALL_DONE==="

        mv /tmp/shim-a /tmp/shim-b
        bundle install 2>&1
        echo "===BROKEN_STATE_DONE==="

        sed -i 's|/tmp/shim-a|/tmp/shim-b|' Gemfile
        gemvault plugin-heal 2>&1
      SH
    end

    it "crashes until `gemvault plugin-heal` clears the index and reinstalls the plugin", :aggregate_failures do
      output, = podman_run(rename_repro_script)
      _, _, after_initial = output.partition("===INITIAL_INSTALL_DONE===")
      broken, _, after_heal = after_initial.partition("===BROKEN_STATE_DONE===")
      expect(broken).to match(BROKEN_PLUGIN_PATH_ERROR), "renamed plugin path should error:\n#{broken}"
      expect(after_heal).to include("Bundle complete!"), "plugin-heal should restore install:\n#{after_heal}"
    end
  end

  context "when the .gemv file is renamed and the Gemfile updated to match" do
    it "reinstalls against the new path without crashing on the stale lockfile entry", :aggregate_failures do
      output, status = install_after_vault_rename
      expect(status).to be_success, "Second bundle install failed:\n#{output}"
      expect(output).not_to include("Could not find vault")
    end
  end

  context "when the Gemfile references the vault by a relative path" do
    it "logs the relative path as written, not the basename", :aggregate_failures do
      output, status = install_with_relative_vault_path
      expect(status).to be_success, "bundle install failed:\n#{output}"
      expect(output).to include("from vault vendor/vendored.gemv")
    end
  end
end

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

  context "when the Gemfile references the vault by a relative path" do
    it "logs the relative path as written, not the basename", :aggregate_failures do
      output, status = install_with_relative_vault_path
      expect(status).to be_success, "bundle install failed:\n#{output}"
      expect(output).to include("from vault vendor/vendored.gemv")
    end
  end
end

RSpec.describe "bundle install with vault source", :integration do
  def bundle_script(gemfile_content, assertions)
    preamble = FixtureScript.preamble(gems: @gems, files: @files, dependencies: @dependencies)
    <<~SH
      #{preamble}
      cd $WORKDIR
      cat > Gemfile <<GEMFILE
      #{gemfile_content}
      GEMFILE
      #{assertions}
    SH
  end

  before do
    @gems = [["vault_test_gem", "1.0.0"]]
    @files = {}
    @dependencies = {}
  end

  it "installs a gem and makes it loadable" do
    output, status = podman_run(bundle_script(
      'source "$WORKDIR/test.gemv", type: :vault do; gem "vault_test_gem"; end',
      <<~SH,
        bundle install
        bundle exec ruby -e "require 'vault_test_gem'; puts VaultTestGem::VERSION"
      SH
    ))
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("1.0.0")
  end

  it "installs multiple gems from one vault" do
    @gems = [["alpha_vault", "1.0.0"], ["beta_vault", "2.0.0"], ["gamma_vault", "3.0.0"]]
    output, status = podman_run(bundle_script(
      <<~GEMFILE,
        source "$WORKDIR/test.gemv", type: :vault do
          gem "alpha_vault"
          gem "beta_vault"
          gem "gamma_vault"
        end
      GEMFILE
      <<~SH,
        bundle install
        bundle list
      SH
    ))
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("alpha_vault (1.0.0)")
    expect(output).to include("beta_vault (2.0.0)")
    expect(output).to include("gamma_vault (3.0.0)")
  end

  it "writes a correct lockfile" do
    output, status = podman_run(bundle_script(
      'source "$WORKDIR/test.gemv", type: :vault do; gem "vault_test_gem"; end',
      <<~SH,
        bundle install
        cat Gemfile.lock
      SH
    ))
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("PLUGIN SOURCE")
    expect(output).to include("type: vault")
    expect(output).to include("vault_test_gem (1.0.0)")
  end

  it "produces an idempotent lockfile" do
    output, status = podman_run(bundle_script(
      'source "$WORKDIR/test.gemv", type: :vault do; gem "vault_test_gem"; end',
      <<~SH,
        bundle install
        cp Gemfile.lock Gemfile.lock.first
        bundle install
        diff Gemfile.lock.first Gemfile.lock
      SH
    ))
    expect(status).to be_success, "Lockfile changed after second install:\n#{output}"
  end

  it "works alongside a rubygems.org source" do
    output, status = podman_run(bundle_script(
      <<~GEMFILE,
        source "https://rubygems.org"
        source "$WORKDIR/test.gemv", type: :vault do
          gem "vault_test_gem"
        end
      GEMFILE
      "bundle install",
    ))
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("Bundle complete!")
  end

  it "installs only requested gems from a vault" do
    @gems = [["want1", "1.0.0"], ["want2", "1.0.0"], ["skipme", "1.0.0"]]
    output, status = podman_run(bundle_script(
      <<~GEMFILE,
        source "$WORKDIR/test.gemv", type: :vault do
          gem "want1"
          gem "want2"
        end
      GEMFILE
      <<~SH,
        bundle install
        bundle list > /tmp/bundle_list.txt
        cat /tmp/bundle_list.txt
        grep -q "want1" /tmp/bundle_list.txt
        grep -q "want2" /tmp/bundle_list.txt
        ! grep -q "skipme" /tmp/bundle_list.txt
      SH
    ))
    expect(status).to be_success, "Failed:\n#{output}"
  end

  it "resolves intra-vault dependencies" do
    @gems = [["depb", "1.0.0"], ["depa", "1.0.0"]]
    @files = { "depa" => { "lib/depa.rb" => "require 'depb'; module Depa; end" } }
    @dependencies = { "depa" => [["depb", "~> 1.0"]] }
    output, status = podman_run(bundle_script(
      <<~GEMFILE,
        source "$WORKDIR/test.gemv", type: :vault do
          gem "depa"
          gem "depb"
        end
      GEMFILE
      "bundle install && bundle list",
    ))
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("depa (1.0.0)")
    expect(output).to include("depb (1.0.0)")
  end

  it "picks the correct version with a constraint" do
    @gems = [["multiver", "1.0.0"], ["multiver", "2.0.0"]]
    @files = {
      "multiver" => { "lib/multiver.rb" => 'module Multiver; VERSION = "replaced"; end' },
    }
    output, status = podman_run(bundle_script(
      <<~GEMFILE,
        source "$WORKDIR/test.gemv", type: :vault do
          gem "multiver", "~> 2.0"
        end
      GEMFILE
      <<~SH,
        bundle install
        bundle exec ruby -e "require 'multiver'; puts Multiver::VERSION"
        bundle list
      SH
    ))
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("multiver (2.0.0)")
    expect(output).not_to include("multiver (1.0.0)")
  end

  context "when a version constraint cannot be satisfied" do
    it "fails with a meaningful error" do
      output, = podman_run(bundle_script(
        'source "$WORKDIR/test.gemv", type: :vault do; gem "vault_test_gem", "~> 2.0"; end',
        "bundle install 2>&1; exit 0",
      ))
      expect(output).to match(/could not find/i)
    end
  end
end

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

  context "when the user runs bundle cache with path: vendor" do
    let(:gemfile) do
      <<~RUBY
        source "$WORKDIR/test.gemv", type: :vault do
          gem "vault_test_gem"
        end
      RUBY
    end

    let(:script) do
      bundle_script(gemfile, <<~SH)
        bundle config set path vendor
        bundle cache
      SH
    end

    it "succeeds" do
      output, status = podman_run(script)

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

        bundle plugin uninstall bundler-source-vault 2>&1
        sed -i 's|/tmp/shim-a|/tmp/shim-b|' Gemfile
        bundle install 2>&1
      SH
    end

    it "crashes until the plugin is uninstalled and reinstalled from the new path" do
      output, = podman_run(rename_repro_script)

      _, _, after_initial = output.partition("===INITIAL_INSTALL_DONE===")
      broken, _, after_workaround = after_initial.partition("===BROKEN_STATE_DONE===")

      expect(broken).to match(/path .* does not exist|plugin paths don't exist|undefined method.*'new' for nil/i),
                        "Expected bundle install to error after the plugin path was renamed. Got:\n#{broken}"

      expect(after_workaround).to include("Bundle complete!"),
                                  "Expected bundle install to succeed after plugin uninstall/reinstall. Got:\n#{after_workaround}"
    end
  end
end

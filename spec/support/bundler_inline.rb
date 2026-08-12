module BundlerInline
  def run_inline_install
    podman_run(inline_script("gemfile(true)"))
  end

  def run_inline_install_without_force
    podman_run(inline_script("gemfile"))
  end

  # `gemvault doctor` in a project whose Gemfile is inline. bundler/inline sets
  # BUNDLE_GEMFILE to a bare "Gemfile", so Bundler's plugin root is the
  # directory the script ran from -- the reporter's project directory.
  def run_doctor_after_inline(followup: "")
    podman_run(<<~SH)
      #{inline_script("gemfile(true)")}
      cd $WORKDIR
      gemvault doctor
      #{followup}
    SH
  end

  def inline_script(gemfile_call)
    <<~SH
      #{GemIndex.serve_preamble}
      #{FixtureScript.preamble}
      cat > $WORKDIR/inline_test.rb <<RUBY
      require "bundler/inline"

      #{gemfile_call} do
        #{GemIndex.source_line}

        source "$WORKDIR/test.gemv", type: :vault do
          gem "vault_test_gem"
        end
      end

      require "vault_test_gem"
      puts VaultTestGem::VERSION
      RUBY
      cd $WORKDIR && ruby $WORKDIR/inline_test.rb
    SH
  end
end

RSpec.configure do |config|
  config.include BundlerInline, :integration
end

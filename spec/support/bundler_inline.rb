module BundlerInline
  def run_inline_install
    podman_run(inline_script("gemfile(true)"))
  end

  def run_inline_install_without_force
    podman_run(inline_script("gemfile"))
  end

  def inline_script(gemfile_call)
    <<~SH
      #{FixtureScript.preamble}
      cat > $WORKDIR/inline_test.rb <<RUBY
      require "bundler/inline"

      #{gemfile_call} do
        source "$WORKDIR/test.gemv", type: :vault do
          gem "vault_test_gem"
        end
      end

      require "vault_test_gem"
      puts VaultTestGem::VERSION
      RUBY
      ruby $WORKDIR/inline_test.rb
    SH
  end
end

RSpec.configure do |config|
  config.include BundlerInline, :integration
end

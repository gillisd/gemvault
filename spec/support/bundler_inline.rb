module BundlerInline
  def run_inline_install
    podman_run(inline_install_script)
  end

  def inline_install_script
    preamble = FixtureScript.preamble
    <<~SH
      #{preamble}
      cat > $WORKDIR/inline_test.rb <<RUBY
      require "bundler/inline"

      gemfile(true) do
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

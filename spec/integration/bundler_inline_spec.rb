RSpec.describe "bundler/inline with vault source", :integration do
  it "discovers the vault plugin and installs the gem" do
    preamble = FixtureScript.preamble
    output, status = podman_run(<<~SH)
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
    expect(status).to be_success, "Failed:\n#{output}"
    expect(output).to include("1.0.0")
  end
end

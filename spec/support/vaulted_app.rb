# Script fragments for the containerized app project whose Gemfile consumes
# the vault built by FixtureScript, with or without the local gem index as a
# rubygems source.
module VaultedApp
  def self.gemfile_with_index
    <<~SH
      cd $WORKDIR
      cat > Gemfile <<GEMFILE
      source "http://127.0.0.1:#{GemIndex::PORT}"

      source "$WORKDIR/test.gemv", type: :vault do
        gem "vault_test_gem"
      end
      GEMFILE
    SH
  end

  def self.gemfile_vault_only
    <<~SH
      cd $WORKDIR
      cat > Gemfile <<GEMFILE
      source "$WORKDIR/test.gemv", type: :vault do
        gem "vault_test_gem"
      end
      GEMFILE
    SH
  end

  # The standard auto-install scenario: serve the tree's gems from the local
  # index, build the fixture vault, reshape the machine as asked, then bundle
  # a project whose Gemfile pulls from both.
  def self.auto_installed_bundle(setup: "")
    <<~SH
      #{GemIndex.serve_preamble}
      #{FixtureScript.preamble}
      #{setup}
      #{gemfile_with_index}
      #{vendored_install}
    SH
  end

  def self.vendored_install
    <<~SH
      bundle config set --local path vendor >/dev/null
      bundle install
    SH
  end
end

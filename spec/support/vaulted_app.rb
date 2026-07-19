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

  def self.vendored_install
    <<~SH
      bundle config set --local path vendor >/dev/null
      bundle install
    SH
  end
end

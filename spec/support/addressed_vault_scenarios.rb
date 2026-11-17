# A project whose Gemfile names its vault as an ordinary gem source address.
# The plugin is installed up front, as the Gemfile no longer infers it, and on
# a Bundler new enough to fire the after-eval hook the address depends on.
module AddressedVaultScenarios
  HOOKED_BUNDLER = "4.1.0".freeze
  ADDRESSED_GEMFILE = 'source "https://gemvault.invalid/test.gemv/" do; gem "vault_test_gem"; end'.freeze

  def install_from_addressed_vault
    run_addressed("bundle install\nbundle exec ruby -e \"require 'vault_test_gem'; puts VaultTestGem::VERSION\"")
  end

  def lock_addressed_vault
    run_addressed("bundle install\ncat Gemfile.lock")
  end

  def install_addressed_vault_twice
    run_addressed(<<~SH)
      bundle install
      cp Gemfile.lock Gemfile.lock.first
      bundle install
      diff Gemfile.lock.first Gemfile.lock
    SH
  end

  def configure_nothing_for_addressed_vault
    run_addressed(<<~SH)
      bundle install
      bundle config list
      cat .bundle/config /root/.bundle/config 2>/dev/null || true
    SH
  end

  def install_addressed_vault_on_image_bundler
    run_bundle(gemfile_content: ADDRESSED_GEMFILE, assertions: <<~SH)
      #{GemIndex.gemrc_pointing_at_index}
      bundle plugin install bundler-source-vault
      bundle install
    SH
  end

  def install_from_absent_addressed_vault
    run_addressed("rm test.gemv\nbundle install")
  end

  def install_from_addressed_vault_in_spaced_project
    run_addressed(<<~SH, project: "$WORKDIR/My Projects")
      bundle install
      bundle exec ruby -e "require 'vault_test_gem'; puts VaultTestGem::VERSION"
      test ! -e .bundle/gemvault
    SH
  end

  private

  def run_addressed(steps, project: "$WORKDIR")
    run_bundle(gemfile_content: ADDRESSED_GEMFILE, assertions: <<~SH)
      gem install --no-document bundler -v #{HOOKED_BUNDLER}
      export BUNDLER_VERSION=#{HOOKED_BUNDLER}
      mkdir -p "#{project}"
      [ "#{project}" = "$WORKDIR" ] || mv Gemfile test.gemv "#{project}/"
      cd "#{project}"
      #{GemIndex.gemrc_pointing_at_index}
      bundle plugin install bundler-source-vault
      #{steps}
    SH
  end
end

RSpec.configure do |config|
  config.include AddressedVaultScenarios, :integration
end

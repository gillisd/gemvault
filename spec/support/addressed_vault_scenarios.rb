# Projects whose Gemfile names its vault as an ordinary gem source address.
module AddressedVaultScenarios
  HOOKED_BUNDLER = "4.1.0".freeze
  ADDRESSED_GEMFILE = 'source "https://gemvault.invalid/test.gemv/" do; gem "vault_test_gem"; end'.freeze
  NESTED_GEMFILE = 'source "https://gemvault.invalid/vendor/test.gemv/" do; gem "vault_test_gem"; end'.freeze
  LOAD = %(bundle exec ruby -e "require 'vault_test_gem'; puts 'loaded ' + VaultTestGem::VERSION").freeze

  def install_from_addressed_vault
    run_addressed("bundle install\n#{LOAD}")
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
      #{LOAD}
      test ! -e .bundle/gemvault
    SH
  end

  def install_from_addressed_vault_beside_another_source
    gemfile = "#{GemIndex.source_line}\ngem \"command_kit\"\n#{ADDRESSED_GEMFILE}"

    run_addressed(<<~SH, gemfile: gemfile)
      bundle install
      #{LOAD}
      bundle exec ruby -e "require 'command_kit'; puts 'loaded command_kit'"
      cat Gemfile.lock
    SH
  end

  def install_from_nested_addressed_vault
    run_addressed(<<~SH, gemfile: NESTED_GEMFILE)
      mkdir vendor
      mv test.gemv vendor/
      bundle install
      #{LOAD}
    SH
  end

  def install_after_moving_the_project
    run_addressed(<<~SH, project: "$WORKDIR/app")
      bundle install
      cd ..
      cp -a app moved
      rm -rf app
      cd moved
      rm -rf .bundle/gemvault
      bundle install
      #{LOAD}
    SH
  end

  def load_after_the_vault_changes
    run_addressed(<<~SH)
      bundle install
      touch test.gemv
      #{LOAD}
      ls .bundle/gemvault/test.gemv | wc -l
    SH
  end

  def install_with_a_plugin_installed_before_the_hook_existed
    run_bundle(gemfile_content: ADDRESSED_GEMFILE, assertions: <<~SH)
      image_bundler=$(bundle --version | awk '{print $NF}')
      gem install --no-document bundler -v #{HOOKED_BUNDLER}
      #{GemIndex.gemrc_pointing_at_index}
      BUNDLER_VERSION=$image_bundler bundle plugin install bundler-source-vault
      export BUNDLER_VERSION=#{HOOKED_BUNDLER}
      bundle install || echo "not redirected"
      rm -rf .bundle/plugin
      bundle plugin install bundler-source-vault
      bundle install
      #{LOAD}
    SH
  end

  private

  def run_addressed(steps, project: "$WORKDIR", gemfile: ADDRESSED_GEMFILE)
    run_bundle(gemfile_content: gemfile, assertions: <<~SH)
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

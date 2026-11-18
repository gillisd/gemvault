# A project whose vault is a plugin source, bundled by a Bundler that predates
# the after-eval hook. Bundler installs the newest plugin for such a source on
# every fresh install, so the plugin has to keep working there. The project is
# shaped like an image build: gems go to a vendor path, and nothing outside the
# project provides gemvault.
module OlderBundlerScenarios
  BUNDLER = "4.0.23".freeze
  LOAD = %(bundle exec ruby -e "require 'vault_test_gem'; puts 'loaded ' + VaultTestGem::VERSION").freeze

  def self.selected
    <<~SH
      gem install --no-document bundler -v #{BUNDLER}
      export BUNDLER_VERSION=#{BUNDLER}
      #{GemIndex.gemrc_pointing_at_index}
      #{DistroRuby.without_system_gemvault}
      echo "running bundler $(bundle --version)"
    SH
  end

  def install_into_vendor_path_on_older_bundler
    run_on_older_bundler(<<~SH)
      bundle config set path vendor
      bundle install
      #{LOAD}
    SH
  end

  def install_twice_on_older_bundler
    run_on_older_bundler(<<~SH)
      bundle config set path vendor
      bundle install
      bundle install
      #{LOAD}
    SH
  end

  def install_frozen_from_a_committed_lockfile_on_older_bundler
    run_on_older_bundler(<<~SH)
      bundle config set path vendor
      bundle install
      cp Gemfile.lock Gemfile.lock.committed
      rm -rf .bundle vendor
      bundle config set path vendor
      bundle config set frozen true
      bundle install
      diff Gemfile.lock.committed Gemfile.lock
      #{LOAD}
    SH
  end

  def address_the_vault_after_leaving_older_bundler(recovery)
    run_on_older_bundler(<<~SH)
      bundle install
      unset BUNDLER_VERSION
      rm Gemfile.lock
      echo "now running bundler $(bundle --version)"
      cat > Gemfile <<GEMFILE
      #{GemIndex.with_source(AddressedVaultScenarios::ADDRESSED_GEMFILE)}
      GEMFILE
      #{recovery}
      bundle install
      #{LOAD}
    SH
  end

  def run_on_older_bundler(steps)
    run_bundle(gemfile_content: single_gem_gemfile, assertions: OlderBundlerScenarios.selected + steps)
  end
end

RSpec.configure do |config|
  config.include OlderBundlerScenarios, :integration
end

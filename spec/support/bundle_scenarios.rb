module BundleScenarios
  def install_and_require_single_gem
    run_bundle(single_gem_gemfile, <<~SH)
      bundle install
      bundle exec ruby -e "require 'vault_test_gem'; puts VaultTestGem::VERSION"
    SH
  end

  def install_multiple_gems
    run_bundle(
      <<~GEMFILE,
        source "$WORKDIR/test.gemv", type: :vault do
          gem "alpha_vault"
          gem "beta_vault"
          gem "gamma_vault"
        end
      GEMFILE
      "bundle install\nbundle list",
      gems: [["alpha_vault", "1.0.0"], ["beta_vault", "2.0.0"], ["gamma_vault", "3.0.0"]],
    )
  end

  def install_and_print_lockfile
    run_bundle(single_gem_gemfile, "bundle install\ncat Gemfile.lock")
  end

  def install_twice_and_diff_lockfile
    run_bundle(single_gem_gemfile, <<~SH)
      bundle install
      cp Gemfile.lock Gemfile.lock.first
      bundle install
      diff Gemfile.lock.first Gemfile.lock
    SH
  end

  def install_alongside_rubygems_source
    run_bundle(
      <<~GEMFILE,
        source "https://rubygems.org"
        source "$WORKDIR/test.gemv", type: :vault do
          gem "vault_test_gem"
        end
      GEMFILE
      "bundle install",
    )
  end

  def install_only_requested_gems
    run_bundle(
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
      gems: [["want1", "1.0.0"], ["want2", "1.0.0"], ["skipme", "1.0.0"]],
    )
  end

  def install_intra_vault_dependencies
    run_bundle(
      <<~GEMFILE,
        source "$WORKDIR/test.gemv", type: :vault do
          gem "depa"
          gem "depb"
        end
      GEMFILE
      "bundle install && bundle list",
      gems: [["depb", "1.0.0"], ["depa", "1.0.0"]],
      files: { "depa" => { "lib/depa.rb" => "require 'depb'; module Depa; end" } },
      dependencies: { "depa" => [["depb", "~> 1.0"]] },
    )
  end

  def install_constrained_version
    run_bundle(
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
      gems: [["multiver", "1.0.0"], ["multiver", "2.0.0"]],
      files: { "multiver" => { "lib/multiver.rb" => 'module Multiver; VERSION = "replaced"; end' } },
    )
  end

  def install_unsatisfiable_constraint
    run_bundle(
      'source "$WORKDIR/test.gemv", type: :vault do; gem "vault_test_gem", "~> 2.0"; end',
      "bundle install 2>&1; exit 0",
    )
  end

  def cache_to_vendor
    run_bundle(single_gem_gemfile, "bundle config set path vendor\nbundle cache")
  end
end

RSpec.configure do |config|
  config.include BundleScenarios, :integration
end

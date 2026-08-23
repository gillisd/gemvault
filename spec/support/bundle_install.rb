module BundleInstall
  def run_bundle(gemfile_content:, assertions:, gems: [["vault_test_gem", "1.0.0"]], files: {}, dependencies: {})
    podman_run(bundle_script(gemfile_content:, assertions:, gems:, files:,
                             dependencies:))
  end

  def bundle_script(gemfile_content:, assertions:, gems:, files:, dependencies:)
    preamble = FixtureScript.preamble(gems:, files:, dependencies:)
    <<~SH
      #{GemIndex.serve_preamble}
      #{preamble}
      cd $WORKDIR
      cat > Gemfile <<GEMFILE
      #{GemIndex.with_source(gemfile_content)}
      GEMFILE
      #{assertions}
    SH
  end

  def single_gem_gemfile
    'source "$WORKDIR/test.gemv", type: :vault do; gem "vault_test_gem"; end'
  end

  def install_with_relative_vault_path
    run_bundle(
      gemfile_content: <<~GEMFILE,
        source "vendor/vendored.gemv", type: :vault do
          gem "rel_log_gem"
        end
      GEMFILE
      assertions: "mkdir vendor\nmv test.gemv vendor/vendored.gemv\nbundle install",
      gems: [["rel_log_gem", "1.0.0"]],
    )
  end

  def bundle_check_after_install
    run_bundle(gemfile_content: single_gem_gemfile, assertions: "bundle install\nbundle check")
  end

  def install_after_vault_rename
    run_bundle(
      gemfile_content: <<~GEMFILE,
        source "$WORKDIR/test.gemv", type: :vault do
          gem "vault_rename_gem"
        end
      GEMFILE
      assertions: <<~SH,
        bundle install
        mv $WORKDIR/test.gemv $WORKDIR/renamed.gemv
        cat > Gemfile <<GEMFILE
        source "$WORKDIR/renamed.gemv", type: :vault do
          gem "vault_rename_gem"
        end
        GEMFILE
        bundle install
      SH
      gems: [["vault_rename_gem", "1.0.0"]],
    )
  end
end

RSpec.configure do |config|
  config.include BundleInstall, :integration
end

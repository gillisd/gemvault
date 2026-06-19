module BundleInstall
  def run_bundle(gemfile_content, assertions, gems: [["vault_test_gem", "1.0.0"]], files: {}, dependencies: {})
    podman_run(bundle_script(gemfile_content, assertions, gems, files, dependencies))
  end

  def bundle_script(gemfile_content, assertions, gems, files, dependencies)
    preamble = FixtureScript.preamble(gems: gems, files: files, dependencies: dependencies)
    <<~SH
      #{preamble}
      cd $WORKDIR
      cat > Gemfile <<GEMFILE
      #{gemfile_content}
      GEMFILE
      #{assertions}
    SH
  end

  def single_gem_gemfile
    'source "$WORKDIR/test.gemv", type: :vault do; gem "vault_test_gem"; end'
  end

  def install_with_relative_vault_path
    run_bundle(
      <<~GEMFILE,
        source "vendor/vendored.gemv", type: :vault do
          gem "rel_log_gem"
        end
      GEMFILE
      "mkdir vendor\nmv test.gemv vendor/vendored.gemv\nbundle install",
      gems: [["rel_log_gem", "1.0.0"]],
    )
  end
end

RSpec.configure do |config|
  config.include BundleInstall, :integration
end

require_relative "fixture_script"
require_relative "gem_index"
require_relative "tree_gems"

# Issue #25: a project locking an older json than the newest gem the machine
# holds. The vault source reads manifest.json only when a vaulted gem is not
# installed -- an incomplete bundle, the reporter's machine -- and that read
# runs inside the bundler process before Bundler.setup's activation check, so
# a `require "json"` there activates the ambient newest copy and the exec
# dies in check_for_activated_spec! instead of saying what is missing. The
# json gems here are inert stand-ins built as fixtures; activation alone is
# the trigger, and the vault fixture is built before the ambient copy is
# installed so the image's own gemvault CLI never sees it.
module JsonActivationScenario
  SCRIPT = <<~SH.freeze
    #{GemIndex.serve_preamble}
    #{FixtureScript.preamble}
    #{FixtureScript.gem_builds(gems: [["json", "98.0.0"], ["json", "99.0.0"]], files: {}, dependencies: {})}
    cp $WORKDIR/gems/json/json-98.0.0.gem /work/index/gems/
    ruby /work/mkindex.rb /work/index
    gem install --local --no-document $WORKDIR/gems/json/json-99.0.0.gem
    cd $WORKDIR
    cat > Gemfile <<GEMFILE
    #{GemIndex.source_line}

    gem "json", "98.0.0"

    source "$WORKDIR/test.gemv", type: :vault do
      gem "vault_test_gem"
    end
    GEMFILE
    bundle install 2>&1
    set +e
    gemvault list $WORKDIR/test.gemv 2>&1
    gem uninstall vault_test_gem 2>&1
    bundle exec ruby -e 'require "vault_test_gem"; puts VaultTestGem::VERSION' 2>&1
    bundle install 2>&1
    bundle exec ruby -e 'require "vault_test_gem"; puts VaultTestGem::VERSION' 2>&1
  SH

  def bundle_exec_with_older_locked_json
    podman_run(SCRIPT)
  end
end

RSpec.configure do |config|
  config.include JsonActivationScenario, :integration
end

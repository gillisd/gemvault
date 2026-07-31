# The reporter's repro for issue #1: a Gemfile-declared `plugin ... path:`
# plugin whose source directory is renamed afterwards. Bundler's plugin index
# pins the absolute path, so every install crashes until `gemvault doctor`
# clears the index and the plugin reinstalls from the corrected Gemfile.
module PluginPathRenameScenario
  BROKEN_PLUGIN_PATH_ERROR = /path .* does not exist|plugin paths don't exist|undefined method.*'new' for nil/i

  Outcome = Data.define(:broken, :healed).freeze

  SCRIPT = <<~SH.freeze
    #{FixtureScript.preamble(gems: [["path_change_gem", "1.0.0"]])}
    set +e
    mkdir -p /tmp/shim-a
    cat > /tmp/shim-a/bundler-source-vault.gemspec <<'GEMSPEC'
    Gem::Specification.new do |s|
      s.name = "bundler-source-vault"
      s.version = "99.0.0"
      s.summary = "test shim"
      s.authors = ["t"]
      s.files = ["plugins.rb"]
      s.require_paths = ["."]
      s.add_dependency "gemvault"
    end
    GEMSPEC
    cat > /tmp/shim-a/plugins.rb <<'PLUGINSRB'
    require "bundler/plugin/vault_source"
    Bundler::Plugin::API.source("vault", Bundler::Plugin::VaultSource)
    PLUGINSRB

    cd $WORKDIR
    cat > Gemfile <<GEMFILE
    source "https://rubygems.org"
    plugin "bundler-source-vault", path: "/tmp/shim-a"
    source "$WORKDIR/test.gemv", type: :vault do
      gem "path_change_gem"
    end
    GEMFILE
    bundle install 2>&1
    echo "===INITIAL_INSTALL_DONE==="

    mv /tmp/shim-a /tmp/shim-b
    bundle install 2>&1
    echo "===BROKEN_STATE_DONE==="

    sed -i 's|/tmp/shim-a|/tmp/shim-b|' Gemfile
    gemvault doctor 2>&1
  SH

  def plugin_path_rename_outcome
    output, = podman_run(SCRIPT)
    _, _, after_initial = output.partition("===INITIAL_INSTALL_DONE===")
    broken, _, healed = after_initial.partition("===BROKEN_STATE_DONE===")
    Outcome.new(broken: broken, healed: healed)
  end
end

RSpec.configure do |config|
  config.include PluginPathRenameScenario, :integration
end

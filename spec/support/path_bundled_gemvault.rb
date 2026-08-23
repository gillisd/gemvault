# A project that bundles gemvault with `path:` -- a contributor checkout, or a
# Gemfile pinned at a working tree. Bundler loads a path gem's
# lib/rubygems_plugin.rb by absolute file path before installing anything, with
# the tree's lib/ absent from $LOAD_PATH and, on a machine without an ambient
# gemvault, nothing to activate: every file the plugin reaches has to arrive by
# require_relative (issue #32). Bundler only performs that load on a run with
# gems left to install, which is why the scenario uninstalls command_kit and
# serves it back from the local index.
module PathBundledGemvault
  def path_bundled_install
    podman_run(<<~SH)
      #{GemIndex.serve_preamble}
      #{DistroRuby.without_system_gemvault}
      APP=$(mktemp -d)
      cd "$APP"
      cat > Gemfile <<GEMFILE
      #{GemIndex.source_line}

      gem "gemvault", path: "/work/src"
      GEMFILE
      bundle install
    SH
  end
end

RSpec.configure do |config|
  config.include PathBundledGemvault, :integration
end

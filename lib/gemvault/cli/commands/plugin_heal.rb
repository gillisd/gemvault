require_relative "../command"

module Gemvault
  class CLI
    module Commands
      # Recovers from a bundler plugin index entry whose stored path no
      # longer exists. Bundler records absolute paths in .bundle/plugin/index
      # for path-installed plugins. Moving or renaming the source directory
      # leaves an invalid path behind — Bundler::Plugin.load_plugin warns
      # "The following plugin paths don't exist: ..." and silently returns,
      # leaving @sources[<type>] nil. The next `source X, type: :vault`
      # crashes inside Bundler::SourceList#add_plugin_source with
      # NoMethodError on nil.
      #
      # Uninstalling clears the broken entry; re-running bundle install
      # triggers Bundler to reinstall the plugin against whatever the
      # current Gemfile declares. Run this from the project directory.
      class PluginHeal < Command
        description "Clear a broken bundler-source-vault plugin index entry and reinstall it"

        def run
          system("bundle", "plugin", "uninstall", "bundler-source-vault")
          exec("bundle", "install")
        end
      end
    end
  end
end

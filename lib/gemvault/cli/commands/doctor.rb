require_relative "../command"
require_relative "../../bundler_gemfile"
require_relative "../../bundler_plugin_root"

module Gemvault
  class CLI
    module Commands
      # Recovers from a bundler plugin index entry whose stored path no
      # longer exists. Bundler records absolute paths in .bundle/plugin/index
      # for path-installed plugins. Moving or renaming the source directory
      # leaves an invalid path behind -- Bundler::Plugin.load_plugin warns
      # "The following plugin paths don't exist: ..." and silently returns,
      # leaving @sources[<type>] nil. The next `source X, type: :vault`
      # crashes inside Bundler::SourceList#add_plugin_source with
      # NoMethodError on nil.
      #
      # Uninstalling clears the broken entry; re-running bundle install
      # triggers Bundler to reinstall the plugin against whatever the
      # current Gemfile declares. Run this from the project directory.
      #
      # A project whose Gemfile is inline has no Gemfile to reinstall from, and
      # keeps its plugins in a root Bundler will not consult unless told to.
      # Both are handled below.
      class Doctor < Command
        PLUGIN = "bundler-source-vault".freeze

        description "Clear a broken bundler-source-vault plugin index entry and reinstall it"

        def run
          system(uninstall_env, "bundle", "plugin", "uninstall", PLUGIN, exception: true)
          reinstall_or_explain
        end

        private

        def gemfile
          @gemfile ||= BundlerGemfile.new
        end

        def plugin_root
          @plugin_root ||= BundlerPluginRoot.new(gemfile: gemfile)
        end

        # bundler/inline's own trick: a non-empty BUNDLE_GEMFILE is the whole of
        # what Bundler::Plugin.root consults to prefer a project's plugin
        # directory over the global one, so setting it reaches the entry that
        # needs clearing. The file it names never has to exist.
        def uninstall_env
          return {} unless plugin_root.unreachable?

          { "BUNDLE_GEMFILE" => "Gemfile" }
        end

        # `bundle install` with no Gemfile prints its entire usage screen and
        # exits 10, which reads as gemvault itself failing. By this point the
        # repair has already happened; only the reinstall is unavailable.
        def reinstall_or_explain
          return exec("bundle", "install") if gemfile.exist?

          puts "Cleared the #{PLUGIN} plugin index at #{plugin_root.local}."
          puts "No Gemfile here to reinstall from -- an inline gemfile installs the plugin"
          puts "again the next time the script runs."
        end
      end
    end
  end
end

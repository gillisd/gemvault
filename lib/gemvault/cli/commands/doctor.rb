require_relative "../command"
require_relative "../../bundler_gemfile"
require_relative "../../bundler_plugin_root"
require_relative "../../ghost_specification"

module Gemvault
  class CLI
    module Commands
      # Recovers from wrecked bundler plugin state. Two wrecks are repaired:
      #
      # A bundler plugin index entry whose stored path no longer exists.
      # Bundler records absolute paths in .bundle/plugin/index for
      # path-installed plugins. Moving or renaming the source directory
      # leaves an invalid path behind -- Bundler::Plugin.load_plugin warns
      # "The following plugin paths don't exist: ..." and silently returns,
      # leaving @sources[<type>] nil. The next `source X, type: :vault`
      # crashes inside Bundler::SourceList#add_plugin_source with
      # NoMethodError on nil. Uninstalling clears the broken entry.
      #
      # A ghost specification: an installation record whose gem directory is
      # gone (see Gemvault::GhostSpecification). Bundler's plugin installer
      # trusts the record and validates plugins.rb against the missing
      # directory instead of the copy it just installed, so every
      # `bundle install` fails with MalformattedPlugin (issue #23). Removing
      # the record lets the reinstall see the machine as it is.
      #
      # Re-running bundle install afterwards triggers Bundler to reinstall
      # the plugin against whatever the current Gemfile declares. Run this
      # from the project directory.
      #
      # A project whose Gemfile is inline has no Gemfile to reinstall from, and
      # keeps its plugins in a root Bundler will not consult unless told to.
      # Both are handled below.
      class Doctor < Command
        description "Repair broken bundler-source-vault plugin state and reinstall the plugin"

        PLUGIN = "bundler-source-vault".freeze

        OWNED_GEMS = %w[gemvault bundler-source-vault].freeze

        PERMISSION_HINT = "(re-run with permissions for that gem home, e.g. sudo gemvault doctor)".freeze

        def run
          begin
            remove_ghost_specifications
          rescue SystemCallError => e
            print_error("#{e.message} #{PERMISSION_HINT}")
            exit(1)
          end
          system(uninstall_env, "bundle", "plugin", "uninstall", PLUGIN, exception: true)
          reinstall_or_explain
        end

        private

        def remove_ghost_specifications
          OWNED_GEMS.flat_map { |name| GhostSpecification.of(name) }.each do |ghost|
            ghost.delete
            puts "Removed ghost specification #{ghost}"
          end
        end

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

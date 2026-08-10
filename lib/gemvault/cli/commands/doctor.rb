require_relative "../command"
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
      # A ghost specification: a gem uninstalled or hand-deleted so that its
      # specifications/<name>-<v>.gemspec survived its gems/<name>-<v>
      # directory. Bundler's plugin installer trusts the record and validates
      # plugins.rb against the missing directory instead of the copy it just
      # installed, so every `bundle install` fails with MalformattedPlugin
      # (issue #23). Removing the record lets the reinstall see the machine
      # as it is.
      #
      # Re-running bundle install afterwards triggers Bundler to reinstall
      # the plugin against whatever the current Gemfile declares. Run this
      # from the project directory.
      class Doctor < Command
        description "Repair broken bundler-source-vault plugin state and reinstall the plugin"

        OWNED_GEMS = %w[gemvault bundler-source-vault].freeze

        def run
          begin
            remove_ghost_specifications
          rescue SystemCallError => e
            print_error(e.message)
            exit(1)
          end
          system("bundle", "plugin", "uninstall", "bundler-source-vault", exception: true)
          exec("bundle", "install")
        end

        private

        def remove_ghost_specifications
          OWNED_GEMS.flat_map { |name| GhostSpecification.of(name) }.each do |ghost|
            ghost.delete
            puts "Removed ghost specification #{ghost.file}"
          end
        end
      end
    end
  end
end

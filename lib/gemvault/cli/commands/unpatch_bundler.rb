require_relative "../command"
require_relative "../../bundler_patch"

module Gemvault
  class CLI
    module Commands
      class UnpatchBundler < Command
        description "Revert the Bundler::Plugin.gemfile_install skip-reinstall patch"

        def run
          summary, results = BundlerPatch.revert!
          if summary == :no_bundler
            print_error("bundler not found in system gems or in ./vendor — nothing to revert")
            exit(1)
          end
          results.each do |file, status|
            puts "#{format_status(status)} #{file}"
          end
        end

        private

        def format_status(status)
          case status
          when :reverted     then "Reverted:    "
          when :not_patched  then "Not patched: "
          end
        end
      end
    end
  end
end

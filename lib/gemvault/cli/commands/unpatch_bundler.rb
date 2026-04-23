require_relative "../command"
require_relative "../../bundler_installation"
require_relative "../../bundler_patch"

module Gemvault
  class CLI
    module Commands
      class UnpatchBundler < Command
        description "Revert the plugin-reinstall fix from every Bundler installation on this machine"

        def run
          installations = BundlerInstallation.discover
          if installations.empty?
            print_error("No bundler installation found in system gems, Ruby stdlib, or ./vendor")
            exit(1)
          end

          patch = BundlerPatch.new
          installations.each do |installation|
            status = patch.revert_from(installation)
            puts "#{format_status(status)} #{installation}"
          end
        end

        private

        def format_status(status)
          case status
          when :reverted     then "Reverted:    "
          when :not_applied  then "Not patched: "
          end
        end
      end
    end
  end
end

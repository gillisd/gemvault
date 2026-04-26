require_relative "../command"
require_relative "../../bundler_installation"
require_relative "../../bundler_patch"

module Gemvault
  class CLI
    module Commands
      # CLI command: reverts the bundler plugin-reinstall patch from every
      # discovered Bundler installation and prints a one-line outcome per file.
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
            outcome = patch.revert_from(installation)
            puts "#{format_outcome(outcome)} #{installation}"
          end
        end

        private

        def format_outcome(outcome)
          case outcome
          in BundlerPatch::Outcome::Reverted   then "Reverted:    "
          in BundlerPatch::Outcome::NotApplied then "Not patched: "
          end
        end
      end
    end
  end
end

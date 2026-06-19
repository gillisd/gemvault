require_relative "../command"
require_relative "../../bundler_installation"
require_relative "../../bundler_patch"

module Gemvault
  class CLI
    module Commands
      # CLI command: applies the bundler plugin-reinstall patch across every
      # discovered Bundler installation and prints a one-line outcome per file.
      class PatchBundler < Command
        description "Apply the plugin-reinstall fix to every Bundler installation on this machine"

        def run
          installations = BundlerInstallation.discover
          if installations.empty?
            print_error("No bundler installation found in system gems, Ruby stdlib, or ./vendor")
            exit(1)
          end

          patch = BundlerPatch.new
          installations.each do |installation|
            outcome = patch.apply_to(installation)
            puts "#{format_outcome(outcome)} #{installation}"
          end
        end

        private

        def format_outcome(outcome)
          case outcome
          in BundlerPatch::Outcome::Applied        then "Patched:        "
          in BundlerPatch::Outcome::AlreadyApplied then "Already patched:"
          end
        end
      end
    end
  end
end

require_relative "../command"
require_relative "../../bundler_installation"
require_relative "../../bundler_patch"

module Gemvault
  class CLI
    module Commands
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
            status = patch.apply_to(installation)
            puts "#{format_status(status)} #{installation}"
          end
        end

        private

        def format_status(status)
          case status
          when :applied         then "Patched:        "
          when :already_applied then "Already patched:"
          end
        end
      end
    end
  end
end

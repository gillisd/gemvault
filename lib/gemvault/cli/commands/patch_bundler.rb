require_relative "../command"
require_relative "../../bundler_patch"

module Gemvault
  class CLI
    module Commands
      class PatchBundler < Command
        description "Apply the Bundler::Plugin.gemfile_install skip-reinstall patch"

        def run
          summary, results = BundlerPatch.apply!
          if summary == :no_bundler
            print_error("bundler not found in system gems or in ./vendor — nothing to patch")
            exit(1)
          end
          results.each do |file, status|
            puts "#{format_status(status)} #{file}"
          end
          exit(1) if results.any? { |_, s| s == :unknown_bundler }
        end

        private

        def format_status(status)
          case status
          when :patched          then "Patched:        "
          when :already_patched  then "Already patched:"
          when :unknown_bundler  then "Unsupported:    "
          end
        end
      end
    end
  end
end

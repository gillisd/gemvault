require_relative "../command"
require_relative "../../gem_reference"

module Gemvault
  class CLI
    module Commands
      # `gemvault remove` subcommand. Parses argv into a GemReference and
      # asks the vault to remove matching gems.
      class Remove < Command
        description "Remove gem(s) from a vault"

        argument :vault, required: true,
                         usage: "VAULT",
                         desc: "Vault file"

        argument :name, required: true,
                        usage: "NAME",
                        desc: "Gem name, or NAME-VERSION"

        argument :version, required: false,
                           usage: "VERSION",
                           desc: "Gem version (omit to remove all versions)"

        option :version, short: "-v",
                         value: { type: String, usage: "VERSION" },
                         desc: "Gem version (overrides positional and NAME-VERSION forms)"

        def run(vault, name, positional_version = nil)
          ref = Gemvault::GemReference.parse(name, version: options[:version] || positional_version)
          with_vault(vault) { |v| report_removal(v.remove(ref)) }
        rescue Gemvault::GemReference::NonExactVersionError => e
          print_error(e.message)
          exit(1)
        end

        private

        def report_removal(count)
          if count.zero?
            print_error("No matching gem found")
            exit(1)
          end
          puts "Removed #{count} gem(s)"
        end
      end
    end
  end
end

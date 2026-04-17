require_relative "../command"

module Gemvault
  class CLI
    module Commands
      class Remove < Command
        description "Remove gem(s) from a vault"

        argument :vault, required: true,
                         usage: "VAULT",
                         desc: "Vault file"

        argument :name, required: true,
                        usage: "NAME",
                        desc: "Gem name"

        argument :version, required: false,
                           usage: "VERSION",
                           desc: "Gem version (omit to remove all versions)"

        def run(vault, name, version = nil)
          with_vault(vault) do |v|
            count = v.remove(name, version)
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
end

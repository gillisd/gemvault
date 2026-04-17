require_relative "../command"

module Gemvault
  class CLI
    module Commands
      class List < Command
        description "List gems in a vault"

        argument :vault, required: true,
                         usage: "VAULT",
                         desc: "Vault file"

        def run(vault)
          with_vault(vault) do |v|
            entries = v.gem_entries
            if entries.empty?
              puts "Vault is empty"
            else
              entries.each { |entry| puts entry }
            end
          end
        end
      end
    end
  end
end

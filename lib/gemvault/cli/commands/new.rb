require_relative "../command"
require_relative "../destination"
require_relative "../../vault_destination"

module Gemvault
  class CLI
    module Commands
      # Creates a new, empty vault file.
      class New < Command
        description "Create a new vault"

        argument :name, required: true,
                        usage: "NAME",
                        desc: "Vault name (auto-appends .gemv)"

        def run(name)
          destination = Destination.new(VaultDestination.new(name), stdout: stdout)
          destination.refuse_existing
          destination.create_parents
          Vault.create(destination.path)
          puts "Created #{destination.path}"
        rescue VaultDestination::Error, SystemCallError => e
          print_error(e.message)
          exit(1)
        end
      end
    end
  end
end

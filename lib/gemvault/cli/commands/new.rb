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
          begin
            destination = build_destination(name)
            destination.refuse_existing
            destination.create_parents
            Vault.create(destination.path)
            puts "Created #{destination.path}"
          rescue VaultDestination::Error, Vault::Error, SystemCallError => e
            print_error(e.message)
            exit(1)
          end
        end

        private

        def build_destination(name)
          vault_destination = VaultDestination.new(name)
          Destination.new(vault_destination, stdout:)
        end
      end
    end
  end
end

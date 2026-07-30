require_relative "../command"
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
          destination = VaultDestination.new(name)
          refuse_existing(destination)
          announce_directory(destination.create_parents)
          Vault.new(destination.path, create: true).close
          puts "Created #{destination.path}"
        rescue VaultDestination::Error, SystemCallError => e
          print_error(e.message)
          exit(1)
        end

        private

        def refuse_existing(destination)
          return unless destination.exist?

          print_error("#{destination.path} already exists")
          exit(1)
        end

        def announce_directory(created)
          puts "Created directory #{created}" if created
        end
      end
    end
  end
end

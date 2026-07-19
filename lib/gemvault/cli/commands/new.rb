require "pathname"
require_relative "../command"

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
          path = Pathname(name.end_with?(".gemv") ? name : "#{name}.gemv")

          if path.exist?
            print_error("#{path} already exists")
            exit(1)
          end

          vault = Vault.new(path, create: true)
          vault.close
          puts "Created #{path}"
        end
      end
    end
  end
end

require_relative "../command"

module Gemvault
  class CLI
    module Commands
      class Add < Command
        description "Add gem files to a vault"

        argument :vault, required: true,
                         usage: "VAULT",
                         desc: "Vault file"

        argument :gems, required: true,
                        repeats: true,
                        usage: "GEM",
                        desc: "Gem files to add"

        def run(vault, *gems)
          with_vault(vault) do |v|
            gems.each do |gem_path|
              v.add(gem_path)
              spec = Gem::Package.new(gem_path).spec
              puts "Added #{spec.name}-#{spec.version}"
            end
          end
        end
      end
    end
  end
end

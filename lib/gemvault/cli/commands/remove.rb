require "rubygems/dependency"
require "rubygems/version"
require_relative "../command"

module Gemvault
  class CLI
    module Commands
      # `gemvault remove` subcommand. Deletes one or all versions of a named gem
      # from a vault. Accepts the version in three forms: a positional `VERSION`
      # argument, a combined `NAME-VERSION` name, or `-v`/`--version VERSION`.
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
          dep = parse_dependency(name, options[:version] || positional_version)
          vault_name, vault_version = dependency_to_vault_args(dep)

          with_vault(vault) do |v|
            count = v.remove(vault_name, vault_version)
            if count.zero?
              print_error("No matching gem found")
              exit(1)
            end
            puts "Removed #{count} gem(s)"
          end
        end

        private

        def parse_dependency(input, explicit_version)
          base_name, combined_version = split_name_version(input)
          version = explicit_version || combined_version
          version ? Gem::Dependency.new(base_name, version) : Gem::Dependency.new(base_name)
        end

        def split_name_version(input)
          idx = input.rindex("-")
          if idx && Gem::Version.correct?(input[(idx + 1)..])
            [input[0...idx], input[(idx + 1)..]]
          else
            [input, nil]
          end
        end

        def dependency_to_vault_args(dep)
          return [dep.name, nil] if dep.requirement.none?

          unless dep.requirement.exact?
            print_error("Version requirement must be an exact version (got: #{dep.requirement})")
            exit(1)
          end

          [dep.name, dep.requirement.requirements.first.last.to_s]
        end
      end
    end
  end
end

require "pathname"
require_relative "../command"

module Gemvault
  class CLI
    module Commands
      # Extracts gem file(s) from a vault back onto the filesystem.
      class Extract < Command
        description "Extract gem file(s) from a vault"

        argument :vault, required: true,
                         usage: "VAULT",
                         desc: "Vault file"

        argument :name, required: true,
                        usage: "NAME",
                        desc: "Gem name"

        argument :version, required: false,
                           usage: "VERSION",
                           desc: "Gem version (omit to extract all versions)"

        option :output, short: "-o",
                        value: { type: String, default: "." },
                        desc: "Output directory"

        def run(vault, name, version = nil)
          output_dir = Pathname(options[:output])

          with_vault(vault) do |v|
            output_dir.mkpath
            entries = matching_entries(vault: v, name:, version:)
            abort_missing_gem(name) if entries.empty?
            extract_entries(vault: v, entries:, output_dir:)
          end
        end

        private

        def matching_entries(vault:, name:, version:)
          entries = vault.gem_entries.select { |entry| entry.name == name }
          version ? entries.select { |entry| entry.version == version } : entries
        end

        def abort_missing_gem(name)
          print_error("No gem named '#{name}' in vault")
          exit(1)
        end

        def extract_entries(vault:, entries:, output_dir:)
          entries.each do |entry|
            data = vault.gem_data(entry)
            (output_dir / entry.filename).binwrite(data)
            puts "Extracted #{entry.filename}"
          end
        end
      end
    end
  end
end

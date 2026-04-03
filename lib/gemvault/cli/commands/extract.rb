# frozen_string_literal: true

require "fileutils"
require_relative "../command"

module Gemvault
  class CLI
    module Commands
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
               value: {type: String, default: "."},
               desc: "Output directory"

        def run(vault, name, version = nil)
          output_dir = options[:output]

          with_vault(vault) do |v|
            ::FileUtils.mkdir_p(output_dir)

            entries = v.gem_entries.select { |e| e.name == name }
            entries = entries.select { |e| e.version == version } if version
            if entries.empty?
              print_error("No gem named '#{name}' in vault")
              exit(1)
            end

            entries.each do |entry|
              data = v.gem_data(entry.name, entry.version, platform: entry.platform)
              File.binwrite(File.join(output_dir, entry.filename), data)
              puts "Extracted #{entry.filename}"
            end
          end
        end
      end
    end
  end
end

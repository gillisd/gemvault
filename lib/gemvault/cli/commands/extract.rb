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

            if version
              data = v.gem_data(name, version)
              filename = "#{name}-#{version}.gem"
              File.binwrite(File.join(output_dir, filename), data)
              puts "Extracted #{filename}"
            else
              entries = v.gem_entries.select { |e| e["name"] == name }
              if entries.empty?
                print_error("No gem named '#{name}' in vault")
                exit(1)
              end
              entries.each do |entry|
                data = v.gem_data(entry["name"], entry["version"], platform: entry["platform"])
                full_name = "#{entry['name']}-#{entry['version']}"
                full_name += "-#{entry['platform']}" if entry["platform"] != "ruby"
                filename = "#{full_name}.gem"
                File.binwrite(File.join(output_dir, filename), data)
                puts "Extracted #{filename}"
              end
            end
          end
        end
      end
    end
  end
end

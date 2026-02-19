# frozen_string_literal: true

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
            entries = v.list
            if entries.empty?
              puts "Vault is empty"
            else
              entries.each do |entry|
                line = "#{entry['name']}-#{entry['version']}"
                line += " (#{entry['platform']})" if entry["platform"] != "ruby"
                puts line
              end
            end
          end
        end
      end
    end
  end
end

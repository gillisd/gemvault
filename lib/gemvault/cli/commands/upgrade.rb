require_relative "../command"
require_relative "../../vault_path"
require_relative "../../vault_upgrade"

module Gemvault
  class CLI
    module Commands
      # Upgrades a vault to the current storage format (e.g. a SQLite Dbvault
      # to a Tarvault), preserving every gem and its timestamp.
      class Upgrade < Command
        description "Upgrade a vault to the current storage format"

        argument :vault, required: true,
                         usage: "VAULT",
                         desc: "Vault file"

        option :dry_run, desc: "Show what would change without modifying the vault"
        option :no_backup, desc: "Do not write a .bak copy before upgrading"

        def run(vault)
          upgrade = Gemvault::VaultUpgrade.new(VaultPath.resolve(vault), backup: !options[:no_backup])
          summary = upgrade.plan
          return report_no_op(vault, summary) if summary.no_op?
          return report_dry_run(vault, summary) if options[:dry_run]

          upgrade.call
          report_upgraded(vault, summary)
        rescue Gemvault::Vault::Error => e
          print_error(e.message)
          exit(1)
        end

        private

        def report_no_op(vault, summary)
          puts "#{vault} is already current (format #{summary.to_version})"
        end

        def report_dry_run(vault, summary)
          puts "Would upgrade #{vault}: #{summary} (#{summary.gem_count} gems)"
        end

        def report_upgraded(vault, summary)
          puts "Upgraded #{vault}: #{summary} (#{summary.gem_count} gems)"
        end
      end
    end
  end
end

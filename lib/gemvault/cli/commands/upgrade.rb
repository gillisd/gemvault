require_relative "../command"
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
          upgrade = Gemvault::VaultUpgrade.new(vault, backup: !options[:no_backup])
          summary = upgrade.plan
          return puts("#{vault} is already current (format #{summary.to_version})") if summary.no_op?
          return puts("Would upgrade #{vault}: #{summary} (#{summary.gem_count} gems)") if options[:dry_run]

          upgrade.call
          puts "Upgraded #{vault}: #{summary} (#{summary.gem_count} gems)"
        rescue Gemvault::Vault::Error => e
          print_error(e.message)
          exit(1)
        end
      end
    end
  end
end

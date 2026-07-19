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
          begin
            upgrade = build_upgrade(vault)
            dispatch(vault:, upgrade:)
          rescue Gemvault::Vault::Error => e
            print_error(e.message)
            exit(1)
          end
        end

        private

        def build_upgrade(vault)
          path = VaultPath.resolve(vault)
          Gemvault::VaultUpgrade.new(path, backup: backup?)
        end

        def backup?
          !options[:no_backup]
        end

        def dispatch(vault:, upgrade:)
          summary = upgrade.plan
          case decision(summary)
          in { no_op: true }
            report_no_op(vault:, summary:)
          in { dry_run: true }
            report_dry_run(vault:, summary:)
          else
            upgrade.call
            report_upgraded(vault:, summary:)
          end
        end

        def decision(summary)
          { no_op: summary.no_op?, dry_run: options[:dry_run] }
        end

        def report_no_op(vault:, summary:)
          puts "#{vault} is already current (format #{summary.to_version})"
        end

        def report_dry_run(vault:, summary:)
          puts "Would upgrade #{vault}: #{summary} (#{summary.gem_count} gems)"
        end

        def report_upgraded(vault:, summary:)
          puts "Upgraded #{vault}: #{summary} (#{summary.gem_count} gems)"
        end
      end
    end
  end
end

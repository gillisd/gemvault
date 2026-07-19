require "command_kit/command"
require_relative "../vault"
require_relative "../vault_path"

module Gemvault
  class CLI
    # Base class for gemvault subcommands; opens a vault and reports vault errors.
    class Command < CommandKit::Command
      private

      def with_vault(locator, create: false, &block)
        Gemvault::Vault.open(VaultPath.resolve(locator), create: create, &block)
      rescue Gemvault::Vault::Error => e
        print_error(e.message)
        exit(1)
      end
    end
  end
end

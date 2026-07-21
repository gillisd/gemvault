require "command_kit/command"
require_relative "../vault"
require_relative "../vault_path"

module Gemvault
  class CLI
    # Base class for gemvault subcommands; opens a vault and reports vault errors.
    class Command < CommandKit::Command
      private

      def with_vault(locator, create: false, &block)
        begin
          path = VaultPath.resolve(locator)
          Gemvault::Vault.open(path, create:, &block)
        rescue Gemvault::Vault::Error => e
          print_error(e.message)
          exit(1)
        end
      end
    end
  end
end

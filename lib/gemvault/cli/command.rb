require "command_kit/command"
require_relative "../vault"

module Gemvault
  class CLI
    class Command < CommandKit::Command
      private

      def with_vault(path, create: false, &block)
        Gemvault::Vault.open(path, create: create, &block)
      rescue Gemvault::Vault::Error => e
        print_error(e.message)
        exit(1)
      end
    end
  end
end

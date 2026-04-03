# frozen_string_literal: true

require "command_kit/command"
require_relative "../vault"

module Gemvault
  class CLI
    class Command < CommandKit::Command
      private

      def with_vault(path, create: false)
        Gemvault::Vault.open(path, create: create) do |vault|
          yield vault
        end
      rescue Gemvault::Vault::Error => e
        print_error(e.message)
        exit(1)
      end
    end
  end
end

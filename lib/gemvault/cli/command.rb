# frozen_string_literal: true

require "command_kit/command"
require_relative "../vault"

module Gemvault
  class CLI
    class Command < CommandKit::Command
      private

      def with_vault(path, create: false)
        vault = Gemvault::Vault.new(path, create: create)
        begin
          yield vault
        ensure
          vault.close
        end
      rescue Gemvault::Vault::Error => e
        print_error(e.message)
        exit(1)
      end
    end
  end
end

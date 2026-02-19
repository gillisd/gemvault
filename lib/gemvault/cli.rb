# frozen_string_literal: true

require "command_kit/command"
require "command_kit/commands/auto_load"
require "command_kit/options/version"
require_relative "version"

module Gemvault
  class CLI < CommandKit::Command
    include CommandKit::Commands::AutoLoad.new(
      dir: "#{__dir__}/cli/commands",
      namespace: "#{name}::Commands"
    )
    include CommandKit::Options::Version

    version Gemvault::VERSION
    command_name "gemvault"
    description "Manage gem vault archives"

    examples [
      "new myvault",
      "add myvault.gemv foo-1.0.0.gem bar-2.0.0.gem",
      "list myvault.gemv",
      "extract myvault.gemv foo -o vendor/"
    ]

    def run(command = nil, *argv)
      if command
        super
      else
        help
      end
    end

    def help
      super
      puts
      puts "Gemfile usage:"
      puts "  # REQUIRED until bundler-source-vault is published to rubygems.org:"
      puts '  plugin "bundler-source-vault", path: "/path/to/gemvault"'
      puts
      puts '  source "myvault.gemv", type: :vault do'
      puts '    gem "foo"'
      puts "  end"
    end
  end
end

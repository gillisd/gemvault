# frozen_string_literal: true

require_relative "lib/bundler/plugin/vault_source"

Bundler::Plugin::API.source("vault", Bundler::Plugin::VaultSource)

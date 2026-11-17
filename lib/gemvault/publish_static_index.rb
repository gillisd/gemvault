# Run as its own Ruby process by Gemvault::VaultPublication:
#
#   ruby publish_static_index.rb VAULT SHELF DIRECTORY
#
# Clears the shelf of every index but DIRECTORY, then publishes VAULT there.

require "fileutils"
require_relative "vault"
require_relative "static_index"

vault_path, shelf, directory = ARGV

begin
  superseded = Dir.glob(File.join(shelf, "*")) - [directory]
  FileUtils.rm_rf(superseded)

  Gemvault::Vault.open(vault_path) { |vault| Gemvault::StaticIndex.new(directory).publish(vault) }
rescue StandardError => e
  abort "gemvault: #{e.message}"
end

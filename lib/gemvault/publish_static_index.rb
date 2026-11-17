# Run as its own Ruby process by Gemvault::VaultPublication:
#
#   ruby publish_static_index.rb VAULT SHELF STAMP
#
# Publishes VAULT as the index for STAMP on the shelf in directory SHELF.
# What it prints is the reason the parent reports when it fails.

require_relative "vault"
require_relative "shelf"

vault_path, shelf, stamp = ARGV

begin
  Gemvault::Shelf.new(shelf).stock(stamp) do |index|
    Gemvault::Vault.open(vault_path) { |vault| index.publish(vault) }
  end
rescue Gemvault::Vault::Error, SystemCallError => e
  abort e.message
end

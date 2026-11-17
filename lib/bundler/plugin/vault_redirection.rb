require_relative "../../gemvault/source_address"
require_relative "../../gemvault/vault_publication"

module Bundler
  module Plugin
    ##
    # Points every gem source a Gemfile addressed to a vault at that vault's
    # contents.
    #
    # A source such as <tt>https://gemvault.invalid/vendor/private.gemv/</tt> is
    # an ordinary gem server address as far as Bundler and the lockfile are
    # concerned. Once the Gemfile has been evaluated, each such address is
    # mirrored to a static gem index published from the vault it names, so
    # Bundler reads the gems from disk and never contacts the host.
    #
    # Each vault has a shelf of its own under the bundle's config directory. The
    # mirror is set for the running process only; nothing is written to the
    # project's or the user's Bundler config.
    class VaultRedirection
      def initialize(definition)
        @definition = definition
      end

      ##
      # Mirrors each vault address in the definition to its published index.
      def apply
        @definition.sources.rubygems_sources
                   .flat_map(&:remotes)
                   .select { |remote| Gemvault::SourceAddress.vaulted?(remote) }
                   .map { |remote| Gemvault::SourceAddress.new(remote) }
                   .each { |address| redirect(address) }
      end

      private

      def redirect(address)
        index = publish(address)

        Bundler.settings.set_command_option("mirror.#{address}", index.url)
      end

      def publish(address)
        begin
          Gemvault::VaultPublication.new(existing_vault(address), shelf: shelf_for(address)).publish
        rescue Gemvault::VaultPublication::Error => e
          raise Bundler::PathError, e.message
        end
      end

      def existing_vault(address)
        relative_path = address.vault_path
        vault_path = File.expand_path(relative_path, Bundler.root)
        return vault_path if File.file?(vault_path)

        raise Bundler::PathError,
              "Could not find vault '#{relative_path}' referenced in Gemfile (relative to #{Bundler.root})"
      end

      def shelf_for(address)
        File.join(Bundler.app_config_path, "gemvault", address.vault_path.gsub("/", "%2F"))
      end
    end
  end
end

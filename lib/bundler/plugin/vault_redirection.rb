require_relative "../../gemvault/source_address"
require_relative "../../gemvault/shelf"
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
    # Each vault has a shelf of its own under the bundle's config directory,
    # set apart by project when that directory is shared between projects. A
    # project where that shelf cannot be addressed or written, such as one
    # whose path holds a space or whose checkout is read-only, keeps its
    # shelves under the user's Bundler cache instead. The mirror is set for the
    # running process only; nothing is written to the project's or the user's
    # Bundler config.
    class VaultRedirection
      def initialize(definition)
        @definition = definition
      end

      ##
      # Mirrors each vault address in the definition to its published index.
      def apply
        @definition
          .sources
          .rubygems_sources
          .flat_map(&:remotes)
          .select { |remote| Gemvault::SourceAddress.vaulted?(remote) }
          .map { |remote| Gemvault::SourceAddress.new(remote) }
          .each { |address| redirect(address) }
      end

      private

      def redirect(address)
        index = publish(address)

        Bundler.settings.set_command_option("mirror.#{address}", index.url)
        confirm(address, index)
        Bundler.ui.debug("gemvault: #{address} is served from #{index.directory}")
      end

      def confirm(address, index)
        return if Bundler.settings.mirror_for(address.to_s).to_s == index.url

        raise Bundler::PathError,
              "Bundler cannot mirror the vault address '#{address}'. Rename the vault file so that no '_' sits " \
              "next to another '_', a '.' or a '-'"
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

        raise Bundler::PathError, absent(relative_path, vault_path)
      end

      def absent(relative_path, vault_path)
        return "Vault '#{relative_path}' referenced in Gemfile is a directory, not a vault file" if
          File.directory?(vault_path)

        "Could not find vault '#{relative_path}' referenced in Gemfile (relative to #{Bundler.root})"
      end

      def shelf_for(address)
        shelves = shelves_for(address)
        shelf = shelves.find(&:usable?)
        return shelf if shelf

        raise Bundler::PathError,
              "Could not publish vault '#{address.vault_path}': neither #{shelves.join(" nor ")} can hold a gem " \
              "index. Each must be writable and its path must hold no spaces and only ASCII characters. Set " \
              "BUNDLE_USER_CACHE to such a directory"
      end

      def shelves_for(address)
        name = address.vault_path.gsub("/", "%2F")

        [File.join(project_shelves, name), File.join(Bundler.user_cache, "gemvault", project, name)]
          .map { |directory| Gemvault::Shelf.new(directory) }
      end

      def project_shelves
        shelves = File.join(Bundler.app_config_path, "gemvault")
        return shelves if shelves.start_with?("#{Bundler.root}/")

        File.join(shelves, project)
      end

      def project
        Bundler::Digest.sha1(Bundler.root.to_s)
      end
    end
  end
end

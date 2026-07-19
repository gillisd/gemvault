require "pathname"
require_relative "vaulted_gem"
require_relative "../../gemvault/vault"
require_relative "../../gemvault/gem_entry"

module Bundler
  module Plugin
    # Bundler plugin source that installs gems from a .gemv vault file. A thin
    # doorway over the Bundler Source API: it resolves the vault path, hands
    # Bundler the gemspecs it can install, and delegates each gem's placement in
    # the bundle to a VaultedGem.
    class VaultSource
      def initialize(opts)
        super
        @vault_path = Pathname(@uri).expand_path(Bundler.root)
        @allow_remote = false
      end

      def fetch_gemspec_files
        validate_vault_exists!

        Gemvault::Vault.open(@vault_path) do |vault|
          vault.gem_entries
               .map { |entry| vault.spec_from_blob(entry) }
               .filter_map { |spec| gemspec_file_for(spec) }
        end
      end

      # Bundler first asks a source, in local mode, which gems are already
      # unpacked so it can tell what still needs installing, then switches to
      # remote mode to resolve and install the rest. A vault gem is not on the
      # load path until it is unpacked, so advertising one that still lives only
      # inside the archive makes Bundler believe it is installed: it skips the
      # install and the later require fails. Advertise not-yet-unpacked gems
      # only once Bundler has asked for remote specs.
      def remote!
        @allow_remote = true
      end

      # The inverse of remote!. Bundler's local-only resolve (Definition#check!,
      # reached by `bundle check`) calls local_only! on every source. The base
      # Bundler::Plugin::API::Source defines no such hook, so without this the
      # command dies with NoMethodError; here it simply stops advertising gems
      # that live only inside the archive.
      def local_only!
        @allow_remote = false
      end

      # Also invoked on every source during resolution (Definition#prefer_local!,
      # for `--prefer-local`). The vault reads from one local file already, so
      # there is no remote to deprioritize.
      def prefer_local!; end

      def install(spec, opts = {})
        gem = VaultedGem.new(spec)
        return gem.adopt if gem.installed? && !opts[:force]

        Bundler.ui.confirm "Installing #{gem.version_message} from vault #{@uri}"
        extract(spec) { |gem_path| gem.install(gem_path: gem_path, build_args: opts[:build_args] || []) }
      end

      def options_to_lock
        {}
      end

      # No source-level install_path to copy: VaultSource#install installs each
      # gem into Bundler.bundle_path via RubyGemsGemInstaller, so the default
      # Source#cache would dereference a non-existent directory.
      def cache(spec, custom_path = nil); end

      def to_s
        "vault at #{@uri}"
      end

      private

      def gemspec_file_for(spec)
        gem = VaultedGem.new(spec)
        return gem.anchor(spec.to_ruby) if gem.installed?
        return nil unless @allow_remote

        write_tmp_gemspec(spec)
      end

      def write_tmp_gemspec(spec)
        tmp_dir = Pathname(Bundler.tmp("vault_source"))
        gemspec_dir = tmp_dir / "specifications"
        gemspec_dir.mkpath
        gemspec = gemspec_dir / "#{spec.full_name}.gemspec"
        gemspec.write(spec.to_ruby)
        gemspec.to_s
      end

      def extract(spec, &)
        Gemvault::Vault.open(@vault_path) do |vault|
          vault.with_gem_file(entry_for(spec), &)
        end
      end

      def entry_for(spec)
        Gemvault::GemEntry.new(name: spec.name, version: spec.version.to_s, platform: spec.platform.to_s)
      end

      def validate_vault_exists!
        return if @vault_path.file?

        raise Bundler::PathError,
              "Could not find vault '#{@uri}' referenced in Gemfile " \
              "(relative to #{Bundler.root})"
      end
    end
  end
end

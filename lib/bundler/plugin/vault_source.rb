require "fileutils"
require_relative "../../gemvault/vault"

module Bundler
  module Plugin
    class VaultSource
      def initialize(opts)
        super
        @vault_path = resolve_vault_path(@uri)
        validate_vault_exists!
      end

      def fetch_gemspec_files
        gemspec_files = []

        Gemvault::Vault.open(@vault_path) do |vault|
          vault.gem_entries.each do |entry|
            spec = vault.spec_from_blob(entry.name, entry.version, entry.platform)
            full_name = spec.full_name
            spec_ruby = spec.to_ruby

            gem_dir = gem_dir_for(full_name)
            if File.directory?(gem_dir)
              gemspec_files << anchor_gemspec(gem_dir, full_name, spec_ruby)
            else
              gemspec_dir = File.join(Bundler.tmp("vault_source"), "specifications")
              FileUtils.mkdir_p(gemspec_dir)
              gemspec_path = File.join(gemspec_dir, "#{full_name}.gemspec")
              File.write(gemspec_path, spec_ruby)
              gemspec_files << gemspec_path
            end
          end
        end

        gemspec_files
      end

      def install(spec, opts = {})
        gem_dir = gem_dir_for(spec.full_name)
        if File.directory?(gem_dir) && !opts[:force]
          Bundler.ui.debug "Using #{version_message(spec)} from vault #{@uri}"
          gemspec_in_gem = File.join(gem_dir, "#{spec.full_name}.gemspec")
          spec.full_gem_path = gem_dir
          spec.loaded_from = gemspec_in_gem
          return nil
        end

        Bundler.ui.confirm "Installing #{version_message(spec)} from vault #{@uri}"

        Gemvault::Vault.open(@vault_path) do |vault|
          vault.with_gem_file(spec.name, spec.version.to_s, platform: spec.platform.to_s) do |gem_path|
            require "bundler/rubygems_gem_installer"

            installer = Bundler::RubyGemsGemInstaller.at(
              gem_path,
              install_dir: Bundler.bundle_path.to_s,
              bin_dir: Bundler.system_bindir.to_s,
              ignore_dependencies: true,
              wrappers: true,
              env_shebang: true,
              build_args: opts[:build_args] || [],
            )

            installed_spec = installer.install

            gem_dir = installed_spec.full_gem_path
            spec.full_gem_path = gem_dir
            spec.loaded_from = anchor_gemspec(gem_dir, spec.full_name, installed_spec.to_ruby)
          end
        end

        spec.post_install_message
      end

      def options_to_lock
        {}
      end

      # No source-level install_path to copy: VaultSource#install installs
      # each gem into Bundler.bundle_path via RubyGemsGemInstaller, so the
      # default Source#cache would dereference a non-existent directory.
      def cache(spec, custom_path = nil); end

      def to_s
        "vault at #{@uri}"
      end

      private

      def version_message(spec)
        message = "#{spec.name} #{spec.version}"
        message += " (#{spec.platform})" if spec.platform != Gem::Platform::RUBY && !spec.platform.nil?
        message
      end

      def resolve_vault_path(uri)
        File.expand_path(uri, Bundler.root.to_s)
      end

      # Bundler computes full_gem_path as dirname(loaded_from) for plugin
      # sources, so the gemspec must live inside the gem directory -- not
      # in specifications/ -- for load paths to resolve correctly.
      def anchor_gemspec(gem_dir, full_name, spec_ruby)
        gemspec_path = File.join(gem_dir, "#{full_name}.gemspec")
        File.write(gemspec_path, spec_ruby) unless File.exist?(gemspec_path)
        gemspec_path
      end

      def gem_dir_for(full_name)
        File.join(Bundler.bundle_path, "gems", full_name)
      end

      def validate_vault_exists!
        return if File.file?(@vault_path)

        raise Bundler::PathError,
              "Could not find vault '#{@uri}' referenced in Gemfile " \
              "(relative to #{Bundler.root})"
      end
    end
  end
end

# frozen_string_literal: true

require "rubygems/package"
require "fileutils"
require "tempfile"
require_relative "../../gemvault/vault"

module Bundler
  module Plugin
    class VaultSource
      def initialize(opts)
        super(opts)
        @vault_path = resolve_vault_path(@uri)
        validate_vault_exists!
      end

      def fetch_gemspec_files
        vault = open_vault
        gemspec_files = []

        begin
          vault.gem_entries.each do |entry|
            spec = vault.spec_from_blob(entry["name"], entry["version"], entry["platform"])
            full_name = spec.full_name
            spec_ruby = spec.to_ruby

            # If the gem is already installed, return the gemspec from inside the
            # gem directory. Bundler computes full_gem_path as dirname(loaded_from)
            # for plugin sources (see rubygems_ext.rb), so loaded_from must be
            # inside the gem directory for the load path to resolve correctly.
            gem_dir = gem_dir_for(full_name)
            if File.directory?(gem_dir)
              gemspec_path = File.join(gem_dir, "#{full_name}.gemspec")
              File.write(gemspec_path, spec_ruby) unless File.exist?(gemspec_path)
              gemspec_files << gemspec_path
            else
              # Not yet installed — write a temp gemspec for resolution
              gemspec_dir = File.join(Bundler.tmp("vault_source"), "specifications")
              FileUtils.mkdir_p(gemspec_dir)
              gemspec_path = File.join(gemspec_dir, "#{full_name}.gemspec")
              File.write(gemspec_path, spec_ruby)
              gemspec_files << gemspec_path
            end
          end
        ensure
          vault.close
        end

        gemspec_files
      end

      def install(spec, opts = {})
        gem_dir = gem_dir_for(spec.full_name)
        if File.directory?(gem_dir) && !opts[:force]
          Bundler.ui.debug "Using #{version_message(spec)} from vault #{File.basename(@vault_path)}"
          gemspec_in_gem = File.join(gem_dir, "#{spec.full_name}.gemspec")
          spec.full_gem_path = gem_dir
          spec.loaded_from = gemspec_in_gem
          return nil
        end

        Bundler.ui.confirm "Installing #{version_message(spec)} from vault #{File.basename(@vault_path)}"

        vault = open_vault
        begin
          data = vault.gem_data(spec.name, spec.version.to_s, platform: spec.platform.to_s)
        ensure
          vault.close
        end

        # Write .gem blob to a temp file for RubyGemsGemInstaller
        tmpfile = Tempfile.new(["vault_gem", ".gem"])
        begin
          tmpfile.binmode
          tmpfile.write(data)
          tmpfile.close

          require "bundler/rubygems_gem_installer"

          installer = Bundler::RubyGemsGemInstaller.at(
            tmpfile.path,
            install_dir: Bundler.bundle_path.to_s,
            bin_dir: Bundler.system_bindir.to_s,
            ignore_dependencies: true,
            wrappers: true,
            env_shebang: true,
            build_args: opts[:build_args] || []
          )

          installed_spec = installer.install

          # For plugin sources, Bundler computes full_gem_path as
          # dirname(loaded_from) (see rubygems_ext.rb). So loaded_from
          # must point INSIDE the gem directory, not in specifications/.
          gem_dir = installed_spec.full_gem_path
          gemspec_in_gem = File.join(gem_dir, "#{spec.full_name}.gemspec")
          unless File.exist?(gemspec_in_gem)
            File.write(gemspec_in_gem, installed_spec.to_ruby)
          end

          spec.full_gem_path = gem_dir
          spec.loaded_from = gemspec_in_gem
        ensure
          tmpfile.unlink
        end

        spec.post_install_message
      end

      def options_to_lock
        {}
      end

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

      def open_vault
        Gemvault::Vault.new(@vault_path)
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

require "pathname"

module Bundler
  module Plugin
    # A gem sourced from a vault as it lives (or will live) inside the bundle.
    # Owns where the gem unpacks, whether it is already installed, installing an
    # extracted .gem file, and anchoring its gemspec inside the gem directory --
    # Bundler derives full_gem_path from dirname(loaded_from), so the gemspec
    # must sit beside the gem, not in specifications/.
    class VaultedGem
      def initialize(spec)
        @spec = spec
        @gem_dir = Bundler.bundle_path.join("gems", spec.full_name)
      end

      def installed?
        @gem_dir.directory?
      end

      def version_message
        message = "#{@spec.name} #{@spec.version}"
        message += " (#{@spec.platform})" if @spec.platform != Gem::Platform::RUBY && !@spec.platform.nil?
        message
      end

      # Point the Bundler spec at the already-unpacked gem.
      def adopt
        Bundler.ui.debug "Using #{version_message} from vault"
        @spec.full_gem_path = @gem_dir.to_s
        @spec.loaded_from = anchor(@spec.to_ruby)
        nil
      end

      # Install the extracted .gem file into the bundle, point the spec at it,
      # and return its post-install message.
      def install(gem_path:, build_args:)
        installed = installer(gem_path: gem_path, build_args: build_args).install
        @spec.full_gem_path = installed.full_gem_path
        @spec.loaded_from = anchor(installed.to_ruby, dir: installed.full_gem_path)
        @spec.post_install_message
      end

      def anchor(spec_ruby, dir: @gem_dir)
        gemspec = Pathname(dir).join("#{@spec.full_name}.gemspec")
        gemspec.write(spec_ruby) unless gemspec.exist?
        gemspec.to_s
      end

      private

      def installer(gem_path:, build_args:)
        require "bundler/rubygems_gem_installer"

        Bundler::RubyGemsGemInstaller.at(
          gem_path,
          install_dir: Bundler.bundle_path.to_s,
          bin_dir: Bundler.system_bindir.to_s,
          ignore_dependencies: true,
          wrappers: true,
          env_shebang: true,
          build_args: build_args,
        )
      end
    end
  end
end

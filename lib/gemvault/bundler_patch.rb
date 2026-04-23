module Gemvault
  # Patches Bundler's Plugin.gemfile_install in place so it no longer
  # reinstalls plugin dependencies on every `bundle install`. The upstream
  # bug (rubygems/rubygems#6630) is that install_definition unconditionally
  # runs install_from_specs without checking whether the plugins are already
  # registered. Upstream PR rubygems/rubygems#6957 fixes this properly but
  # hasn't shipped in a Bundler release.
  #
  # The fix here is the three-line short-circuit that the original reporter
  # proposed: before calling Installer.new.install_definition, filter plugins
  # that are already in the index and return early if none remain. That's
  # small, contained, and idempotent.
  module BundlerPatch
    MARKER = "# gemvault-bundler-patch: skip-reinstalled-plugins".freeze

    INSTALL_CALL = "installed_specs = Installer.new.install_definition(definition)".freeze

    FIX_INSERT = "#{MARKER}\n" \
                 "        return if definition.dependencies.map(&:name).all? { |n| index.installed?(n) }\n" \
                 "        #{INSTALL_CALL}".freeze

    module_function

    def apply!
      results = plugin_rb_paths.map { |file| [file, patch_file(file)] }
      return [:no_bundler, []] if results.empty?

      [summarize(results.map(&:last)), results]
    end

    def revert!
      results = plugin_rb_paths.map { |file| [file, revert_file(file)] }
      return [:no_bundler, []] if results.empty?

      [summarize(results.map(&:last)), results]
    end

    def patch_file(file)
      source = File.read(file)
      return :already_patched if source.include?(MARKER)
      return :unknown_bundler unless source.include?(INSTALL_CALL)

      File.write(file, source.sub(INSTALL_CALL, FIX_INSERT))
      :patched
    end

    def revert_file(file)
      source = File.read(file)
      return :not_patched unless source.include?(MARKER)

      File.write(file, source.sub(FIX_INSERT, INSTALL_CALL))
      :reverted
    end

    def plugin_rb_paths
      (system_paths + stdlib_paths + vendored_paths).uniq.select { |path| File.exist?(path) }
    end

    def system_paths
      Gem::Specification.find_all_by_name("bundler")
                        .map { |spec| File.join(spec.full_gem_path, "lib/bundler/plugin.rb") }
    end

    def stdlib_paths
      Dir.glob(File.join(RbConfig::CONFIG["rubylibdir"] || "", "bundler/plugin.rb")) +
        Dir.glob(File.join(RbConfig::CONFIG["sitelibdir"] || "", "bundler/plugin.rb"))
    end

    def vendored_paths
      Dir.glob("vendor/ruby/*/gems/bundler-*/lib/bundler/plugin.rb") +
        Dir.glob(".bundle/ruby/*/gems/bundler-*/lib/bundler/plugin.rb")
    end

    def summarize(statuses)
      return statuses.first if statuses.uniq.length == 1

      :mixed
    end
  end
end

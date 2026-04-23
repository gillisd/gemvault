require "test_helper"
require "gemvault/bundler_installation"
require "gemvault/bundler_patch"

class BundlerPatchTest < Minitest::Test
  PRISTINE_PLUGIN_RB = <<~RUBY.freeze
    module Bundler
      module Plugin
        def gemfile_install
          Bundler.settings.temporary(frozen: false) do
            definition = build

            return if definition.dependencies.empty?

            plugins = definition.dependencies.map(&:name)
            installed_specs = Installer.new.install_definition(definition)

            save_plugins plugins, installed_specs, builder.inferred_plugins
          end
        end
      end
    end
  RUBY

  def setup
    @tmpdir = Pathname(Dir.mktmpdir("bundler_patch_test"))
    @plugin_rb = @tmpdir / "plugin.rb"
    @plugin_rb.write(PRISTINE_PLUGIN_RB)
    @installation = Gemvault::BundlerInstallation.new(@plugin_rb)
    @patch = Gemvault::BundlerPatch.new
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_apply_to_pristine_installation_returns_applied
    assert_equal :applied, @patch.apply_to(@installation)
  end

  def test_apply_to_pristine_installation_inserts_the_skip_check
    @patch.apply_to(@installation)

    assert_includes @plugin_rb.read, Gemvault::BundlerPatch::MARKER
    assert_includes @plugin_rb.read, "return if definition.dependencies.map(&:name).all?"
  end

  def test_apply_to_already_patched_installation_is_a_noop
    @patch.apply_to(@installation)
    before = @plugin_rb.read

    assert_equal :already_applied, @patch.apply_to(@installation)
    assert_equal before, @plugin_rb.read
  end

  def test_revert_from_patched_installation_returns_reverted
    @patch.apply_to(@installation)

    assert_equal :reverted, @patch.revert_from(@installation)
  end

  def test_revert_from_patched_installation_restores_pristine_content
    @patch.apply_to(@installation)
    @patch.revert_from(@installation)

    assert_equal PRISTINE_PLUGIN_RB, @plugin_rb.read
  end

  def test_revert_from_pristine_installation_is_a_noop
    assert_equal :not_applied, @patch.revert_from(@installation)
    assert_equal PRISTINE_PLUGIN_RB, @plugin_rb.read
  end

  def test_apply_then_revert_round_trips_to_the_exact_byte_stream
    @patch.apply_to(@installation)
    @patch.revert_from(@installation)

    assert_equal PRISTINE_PLUGIN_RB, @plugin_rb.read
  end
end

class BundlerInstallationTest < Minitest::Test
  def test_installation_exposes_its_plugin_rb_as_a_pathname
    path = Pathname("/tmp/some/bundler/plugin.rb")
    installation = Gemvault::BundlerInstallation.new(path)

    assert_equal path, installation.plugin_rb
    assert_kind_of Pathname, installation.plugin_rb
  end

  def test_installation_accepts_a_string_and_wraps_it_in_pathname
    installation = Gemvault::BundlerInstallation.new("/tmp/some/bundler/plugin.rb")

    assert_kind_of Pathname, installation.plugin_rb
  end

  def test_installations_are_equal_when_plugin_rb_matches
    a = Gemvault::BundlerInstallation.new("/same/path/plugin.rb")
    b = Gemvault::BundlerInstallation.new("/same/path/plugin.rb")

    assert_equal a, b
    assert_equal a.hash, b.hash
  end

  def test_installations_are_unequal_when_plugin_rb_differs
    a = Gemvault::BundlerInstallation.new("/one/plugin.rb")
    b = Gemvault::BundlerInstallation.new("/two/plugin.rb")

    refute_equal a, b
  end
end

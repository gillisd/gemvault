require "test_helper"
require "gemvault/bundler_patch"

class BundlerPatchTest < Minitest::Test
  PRISTINE_PLUGIN_RB = <<~RUBY
    module Bundler
      module Plugin
        def gemfile_install(gemfile = nil, &inline)
          Bundler.settings.temporary(frozen: false, deployment: false) do
            builder = DSL.new
            builder.eval_gemfile(gemfile)
            definition = builder.to_definition(nil, true)

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
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_patch_file_rewrites_pristine_source_with_skip_check
    assert_equal :patched, Gemvault::BundlerPatch.patch_file(@plugin_rb.to_s)

    source = @plugin_rb.read
    assert_includes source, Gemvault::BundlerPatch::MARKER
    assert_includes source, "return if definition.dependencies.map(&:name).all? { |n| index.installed?(n) }"
  end

  def test_patch_file_is_idempotent
    Gemvault::BundlerPatch.patch_file(@plugin_rb.to_s)
    after_first = @plugin_rb.read

    assert_equal :already_patched, Gemvault::BundlerPatch.patch_file(@plugin_rb.to_s)
    assert_equal after_first, @plugin_rb.read
  end

  def test_patch_file_refuses_unknown_bundler_source
    @plugin_rb.write("module Bundler; module Plugin; def gemfile_install; :something_else; end; end; end")

    assert_equal :unknown_bundler, Gemvault::BundlerPatch.patch_file(@plugin_rb.to_s)
  end

  def test_revert_file_restores_pristine_source
    Gemvault::BundlerPatch.patch_file(@plugin_rb.to_s)

    assert_equal :reverted, Gemvault::BundlerPatch.revert_file(@plugin_rb.to_s)
    assert_equal PRISTINE_PLUGIN_RB, @plugin_rb.read
  end

  def test_revert_file_is_a_noop_on_unpatched_source
    assert_equal :not_patched, Gemvault::BundlerPatch.revert_file(@plugin_rb.to_s)
    assert_equal PRISTINE_PLUGIN_RB, @plugin_rb.read
  end

  def test_patch_followed_by_revert_round_trips_to_the_exact_byte_stream
    Gemvault::BundlerPatch.patch_file(@plugin_rb.to_s)
    Gemvault::BundlerPatch.revert_file(@plugin_rb.to_s)

    assert_equal PRISTINE_PLUGIN_RB, @plugin_rb.read
  end
end

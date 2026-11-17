require "bundler"
require "bundler/plugin/vault_redirection"

RSpec.describe Bundler::Plugin::VaultRedirection do
  include GemFixtures

  subject(:redirection) { described_class.new(definition) }

  let(:project) { gem_dir }
  let(:user_cache) { gem_dir / "cache" }
  let(:published_root) { project / ".bundle" / "gemvault" }
  let(:shelf_url) { "file://#{published_root}/test.gemv/" }
  let(:settings) { instance_spy(Bundler::Settings) }
  let(:source) { Struct.new(:remotes) }
  let(:sources) { Struct.new(:rubygems_sources) }
  let(:definition) { Struct.new(:sources).new(sources.new([source.new(remotes)])) }

  before do
    allow(Bundler).to receive_messages(root: project, app_config_path: project / ".bundle",
                                       user_cache: user_cache, settings: settings)
  end

  context "when a source is addressed to a vault" do
    let(:remotes) { ["https://gemvault.invalid/test.gemv/"] }

    before do
      current_tarvault
      redirection.apply
    end

    it "publishes the vault as a gem index under the bundle's config directory" do
      expect(published_root.glob("test.gemv/*/gems/foo-1.0.0.gem").size).to eq(1)
    end

    it "mirrors the address to that index" do
      expect(settings).to have_received(:set_command_option)
        .with("mirror.https://gemvault.invalid/test.gemv/", a_string_starting_with(shelf_url))
    end
  end

  context "when the project path cannot be written as an address" do
    let(:project) { gem_dir / "My Projects" }
    let(:vault_path) { project / "test.gemv" }
    let(:remotes) { ["https://gemvault.invalid/test.gemv/"] }

    before do
      project.mkpath
      current_tarvault
      redirection.apply
    end

    it "publishes the vault under the user's Bundler cache" do
      expect(user_cache.glob("gemvault/*/test.gemv/*/gems/foo-1.0.0.gem").size).to eq(1)
    end

    it "mirrors the address to that index" do
      expect(settings).to have_received(:set_command_option)
        .with("mirror.https://gemvault.invalid/test.gemv/", a_string_starting_with("file://#{user_cache}/gemvault/"))
    end

    it "publishes nothing inside the project" do
      expect(published_root).not_to exist
    end
  end

  context "when two projects fall back to the user's Bundler cache" do
    let(:project) { gem_dir / "My Projects" }
    let(:vault_path) { project / "test.gemv" }
    let(:remotes) { ["https://gemvault.invalid/test.gemv/"] }

    def other_project = gem_dir / "Other Projects"

    before do
      project.mkpath
      current_tarvault
      redirection.apply
      other_project.mkpath
      FileUtils.cp(vault_path, other_project / "test.gemv")
      allow(Bundler).to receive_messages(root: other_project, app_config_path: other_project / ".bundle")
      described_class.new(definition).apply
    end

    it "keeps a shelf for each project" do
      expect(user_cache.glob("gemvault/*/test.gemv").size).to eq(2)
    end
  end

  context "when neither the project nor the user's Bundler cache can be written as an address" do
    let(:project) { gem_dir / "My Projects" }
    let(:user_cache) { gem_dir / "My Cache" }
    let(:vault_path) { project / "test.gemv" }
    let(:remotes) { ["https://gemvault.invalid/test.gemv/"] }

    before do
      project.mkpath
      current_tarvault
    end

    it "raises a path error naming the vault" do
      expect { redirection.apply }.to raise_error(Bundler::PathError, /test\.gemv/)
    end

    it "names the setting that moves the cache" do
      expect { redirection.apply }.to raise_error(Bundler::PathError, /BUNDLE_USER_CACHE/)
    end
  end

  context "when no source is addressed to a vault" do
    let(:remotes) { ["https://rubygems.org/"] }

    it "sets no mirror" do
      redirection.apply
      expect(settings).not_to have_received(:set_command_option)
    end
  end

  context "when the addressed vault does not exist" do
    let(:remotes) { ["https://gemvault.invalid/absent.gemv/"] }

    it "raises a path error naming the vault" do
      expect { redirection.apply }.to raise_error(Bundler::PathError, /absent\.gemv/)
    end
  end
end

require "bundler"
require "bundler/plugin/vault_redirection"

RSpec.describe Bundler::Plugin::VaultRedirection do
  include GemFixtures

  subject(:redirection) { described_class.new(definition) }

  let(:project) { gem_dir }
  let(:app_config) { project / ".bundle" }
  let(:user_cache) { gem_dir / "cache" }
  let(:settings) { Bundler::Settings.new(gem_dir / "settings") }
  let(:ui) { instance_spy(Bundler::UI::Silent) }
  let(:address) { "https://gemvault.invalid/test.gemv/" }
  let(:remotes) { [Gem::URI(address)] }

  def definition
    source = Struct.new(:remotes).new(remotes)
    sources = Struct.new(:rubygems_sources).new([source])

    Struct.new(:sources).new(sources)
  end

  def mirror
    settings.mirror_for(address).to_s
  end

  before do
    project.mkpath
    allow(Bundler).to receive_messages(root: project, app_config_path: app_config, user_cache: user_cache,
                                       settings: settings, ui: ui)
  end

  context "when a source is addressed to a vault" do
    before do
      current_tarvault
      redirection.apply
    end

    it "publishes the vault as a gem index under the bundle's config directory" do
      expect(app_config.glob("gemvault/test.gemv/*/gems/foo-1.0.0.gem").size).to eq(1)
    end

    it "mirrors the address to that index" do
      expect(mirror).to start_with("file://#{app_config}/gemvault/test.gemv/")
    end

    it "reports where the index is served from" do
      expect(ui).to have_received(:debug).with(/served from/)
    end
  end

  context "when the vault sits in a subdirectory" do
    let(:address) { "https://gemvault.invalid/vendor/test.gemv/" }
    let(:vault_path) { project / "vendor" / "test.gemv" }

    before do
      vault_path.dirname.mkpath
      current_tarvault
      redirection.apply
    end

    it "publishes on a shelf named for the whole vault path" do
      expect(app_config.glob("gemvault/vendor%2Ftest.gemv/*/gems/foo-1.0.0.gem").size).to eq(1)
    end

    it "mirrors the address to that index" do
      expect(mirror).to start_with("file://#{app_config}/gemvault/vendor%2Ftest.gemv/")
    end
  end

  context "when two sources are addressed to vaults" do
    let(:other_address) { "https://gemvault.invalid/other.gemv/" }
    let(:remotes) { [Gem::URI(address), Gem::URI(other_address)] }

    before do
      current_tarvault
      FileUtils.cp(vault_path, project / "other.gemv")
      redirection.apply
    end

    it "mirrors the first" do
      expect(mirror).to start_with("file://#{app_config}/gemvault/test.gemv/")
    end

    it "mirrors the second" do
      expect(settings.mirror_for(other_address).to_s).to start_with("file://#{app_config}/gemvault/other.gemv/")
    end
  end

  context "when the project path cannot be written as an address" do
    let(:project) { gem_dir / "My Projects" }
    let(:vault_path) { project / "test.gemv" }

    before do
      current_tarvault
      redirection.apply
    end

    it "publishes the vault under the user's Bundler cache" do
      expect(user_cache.glob("gemvault/*/test.gemv/*/gems/foo-1.0.0.gem").size).to eq(1)
    end

    it "mirrors the address to that index" do
      expect(mirror).to start_with("file://#{user_cache}/gemvault/")
    end

    it "publishes nothing inside the project" do
      expect(app_config / "gemvault").not_to exist
    end
  end

  context "when two projects fall back to the user's Bundler cache" do
    let(:project) { gem_dir / "My Projects" }
    let(:vault_path) { project / "test.gemv" }

    def other_project = gem_dir / "Other Projects"

    before do
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

  context "when the project directory is read-only" do
    let(:project) { gem_dir / "app" }
    let(:vault_path) { project / "test.gemv" }

    before do
      current_tarvault
      project.chmod(0o555)
      redirection.apply
    end

    after { project.chmod(0o755) }

    it "publishes the vault under the user's Bundler cache" do
      expect(mirror).to start_with("file://#{user_cache}/gemvault/")
    end
  end

  context "when the bundle's config directory is outside the project" do
    let(:project) { gem_dir / "app" }
    let(:app_config) { gem_dir / "global" }
    let(:vault_path) { project / "test.gemv" }

    before do
      current_tarvault
      redirection.apply
    end

    it "keeps the shelf apart from other projects that share the directory" do
      expect(app_config.glob("gemvault/#{"[0-9a-f]" * 40}/test.gemv/*/gems/foo-1.0.0.gem").size).to eq(1)
    end
  end

  context "when neither the project nor the user's Bundler cache can hold an index" do
    let(:project) { gem_dir / "My Projects" }
    let(:user_cache) { gem_dir / "My Cache" }
    let(:vault_path) { project / "test.gemv" }

    before { current_tarvault }

    it "raises a path error naming the vault" do
      expect { redirection.apply }.to raise_error(Bundler::PathError, /test\.gemv/)
    end

    it "names the setting that moves the cache" do
      expect { redirection.apply }.to raise_error(Bundler::PathError, /BUNDLE_USER_CACHE/)
    end
  end

  context "when Bundler cannot carry the vault path in a mirror" do
    let(:address) { "https://gemvault.invalid/my__vault.gemv/" }
    let(:vault_path) { project / "my__vault.gemv" }

    before { current_tarvault }

    it "raises a path error naming the address" do
      expect { redirection.apply }
        .to raise_error(Bundler::PathError, a_string_including("cannot carry the vault path 'my__vault.gemv'"))
    end
  end

  context "when the vault path climbs out of the project" do
    let(:project) { gem_dir / "app" }
    let(:address) { "https://gemvault.invalid/../test.gemv/" }

    before { current_tarvault }

    it "raises a path error saying Bundler cannot carry the path" do
      expect { redirection.apply }.to raise_error(Bundler::PathError, /cannot carry the vault path '\.\.\/test\.gemv'/)
    end
  end

  context "when another mirror setting takes over the address" do
    before do
      current_tarvault
      settings.set_command_option("mirror.all", "https://mirror.example/gems/")
    end

    it "raises a path error naming the mirror that won" do
      expect { redirection.apply }.to raise_error(Bundler::PathError, %r{mirror\.example/gems})
    end
  end

  context "when the vault path starts with a tilde" do
    let(:address) { "https://gemvault.invalid/~/test.gemv/" }
    let(:vault_path) { project / "~" / "test.gemv" }

    before do
      vault_path.dirname.mkpath
      current_tarvault
      redirection.apply
    end

    it "finds it inside the project" do
      expect(mirror).to start_with("file://#{app_config}/gemvault/")
    end
  end

  context "when the vault cannot be published" do
    before { vault_path.write("not a vault") }

    it "raises a path error saying why" do
      expect { redirection.apply }.to raise_error(Bundler::PathError, /as a gem index: \S/)
    end
  end

  context "when no source is addressed to a vault" do
    let(:address) { "https://rubygems.org/" }

    it "sets no mirror" do
      redirection.apply
      expect(mirror).to eq(address)
    end
  end

  context "when the addressed vault does not exist" do
    let(:address) { "https://gemvault.invalid/absent.gemv/" }

    it "raises a path error naming the vault" do
      expect { redirection.apply }
        .to raise_error(Bundler::PathError, a_string_including("Could not find vault 'absent.gemv'"))
    end
  end

  context "when the addressed path is a directory" do
    before { vault_path.mkpath }

    it "raises a path error saying so" do
      expect { redirection.apply }.to raise_error(Bundler::PathError, /is a directory/)
    end
  end
end

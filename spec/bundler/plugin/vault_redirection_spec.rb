require "bundler"
require "bundler/plugin/vault_redirection"

RSpec.describe Bundler::Plugin::VaultRedirection do
  include GemFixtures

  subject(:redirection) { described_class.new(definition) }

  let(:published_root) { gem_dir / ".bundle" / "gemvault" }
  let(:shelf_url) { "file://#{published_root}/test.gemv/" }
  let(:settings) { instance_spy(Bundler::Settings) }
  let(:source) { Struct.new(:remotes) }
  let(:sources) { Struct.new(:rubygems_sources) }
  let(:definition) { Struct.new(:sources).new(sources.new([source.new(remotes)])) }

  before do
    allow(Bundler).to receive_messages(root: gem_dir, app_config_path: gem_dir / ".bundle", settings: settings)
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

require "gemvault/shelf"
require "gemvault/vault_publication"
require "open3"

RSpec.describe Gemvault::VaultPublication do
  include GemFixtures

  subject(:publication) { described_class.new(vault_path, shelf: shelf) }

  let(:shelf_directory) { gem_dir / "shelf" }
  let(:shelf) { Gemvault::Shelf.new(shelf_directory) }
  let(:lib) { File.expand_path("../../lib", __dir__) }

  def published_gems
    shelf_directory.glob("*/gems/*.gem").map { |gem| gem.basename.to_s }
  end

  def indexes
    shelf_directory.glob("*-*-*")
  end

  def age(path)
    past = Time.now - 3600
    File.utime(past, past, path)
  end

  describe "#publish" do
    before { current_tarvault }

    it "publishes the vault's gems on the shelf" do
      publication.publish
      expect(published_gems).to eq(["foo-1.0.0.gem"])
    end

    it "returns the index it published" do
      expect(publication.publish).to be_published
    end

    it "keeps one index per vault" do
      publication.publish
      expect(indexes.size).to eq(1)
    end

    context "when the vault has not changed since it was published" do
      it "keeps the published index" do
        first = publication.publish.url
        expect(described_class.new(vault_path, shelf: shelf).publish.url).to eq(first)
      end

      it "leaves the published files untouched" do
        publication.publish
        marker = indexes.first / "untouched"
        marker.write("")
        described_class.new(vault_path, shelf: shelf).publish
        expect(marker).to exist
      end
    end

    context "when the vault has changed since it was published" do
      before do
        publication.publish
        open_vault { |vault| vault.add(build_gem(name: "bar", version: "2.0.0")) }
        age(vault_path)
        described_class.new(vault_path, shelf: shelf).publish
      end

      it "publishes the vault's current gems" do
        expect(published_gems).to contain_exactly("foo-1.0.0.gem", "bar-2.0.0.gem")
      end

      it "removes the superseded index" do
        expect(indexes.size).to eq(1)
      end
    end

    context "when only the vault's modification time changes" do
      it "publishes a new index" do
        first = publication.publish.url
        age(vault_path)
        expect(described_class.new(vault_path, shelf: shelf).publish.url).not_to eq(first)
      end
    end

    context "when only the vault's size changes" do
      before do
        modified = File.mtime(vault_path)
        publication.publish
        open_vault { |vault| vault.add(build_gem(name: "bar", version: "2.0.0")) }
        File.utime(modified, modified, vault_path)
        described_class.new(vault_path, shelf: shelf).publish
      end

      it "publishes the vault's current gems" do
        expect(published_gems).to contain_exactly("foo-1.0.0.gem", "bar-2.0.0.gem")
      end
    end

    context "when called from the process that is publishing" do
      around do |example|
        ENV[described_class::PUBLISHING] = "1"
        example.run
      ensure
        ENV.delete(described_class::PUBLISHING)
      end

      it "refuses to publish again" do
        expect { publication.publish }.to raise_error(Gemvault::VaultPublication::Error, /already publishing/)
      end
    end

    context "when the caller runs under Bundler" do
      let(:loaded) { gem_dir / "bundler_setup_loaded" }
      let(:bundler_setup) { gem_dir / "setup.rb" }

      around do |example|
        bundler_setup.write("File.write(#{loaded.to_s.inspect}, %q(loaded))")
        ENV["BUNDLER_SETUP"] = bundler_setup.to_s
        example.run
      ensure
        ENV.delete("BUNDLER_SETUP")
      end

      it "publishes without loading Bundler into the publishing process" do
        publication.publish
        expect(loaded).not_to exist
      end
    end

    context "when the caller's RUBYOPT preloads a file" do
      let(:loaded) { gem_dir / "rubyopt_loaded" }
      let(:preload) { gem_dir / "preload.rb" }

      around do |example|
        preload.write("File.write(#{loaded.to_s.inspect}, %q(loaded))")
        original = ENV.fetch("RUBYOPT", nil)
        ENV["RUBYOPT"] = "-r#{preload}"
        example.run
      ensure
        ENV["RUBYOPT"] = original
      end

      it "publishes without preloading it into the publishing process" do
        publication.publish
        expect(loaded).not_to exist
      end
    end

    context "when the file is not a vault" do
      before { vault_path.write("not a vault") }

      it "raises naming the vault" do
        expect { publication.publish }.to raise_error(Gemvault::VaultPublication::Error, /test\.gemv/)
      end

      it "says why it could not be published" do
        expect { publication.publish }.to raise_error(Gemvault::VaultPublication::Error, /as a gem index: \S/)
      end
    end

    context "when the vault file is missing" do
      before { vault_path.delete }

      it "raises saying it could not read the vault" do
        expect { publication.publish }.to raise_error(Gemvault::VaultPublication::Error, /could not read vault/)
      end
    end

    context "when the publishing process cannot start" do
      before { allow(Gem).to receive(:ruby).and_return((gem_dir / "no-ruby").to_s) }

      it "raises saying so" do
        expect { publication.publish }.to raise_error(Gemvault::VaultPublication::Error, /could not start/)
      end
    end
  end

  describe "the gems it activates in the calling process" do
    let(:outside_the_bundle) { described_class::BUNDLER_VARIABLES.to_h { |variable| [variable, nil] } }
    let(:script) do
      <<~RUBY
        before = Gem.loaded_specs.keys
        #{preamble}
        require "gemvault/source_address"
        require "gemvault/vault_publication"
        Gemvault::SourceAddress.new("https://gemvault.invalid/test.gemv/")
        shelf = Gemvault::Shelf.new(ARGV.fetch(1))
        shelf.usable?
        Gemvault::VaultPublication.new(ARGV.fetch(0), shelf: shelf).publish
        puts Gem.loaded_specs.keys - before
      RUBY
    end
    let(:preamble) { "" }

    def activated
      Open3.capture2e(outside_the_bundle, RbConfig.ruby, "-I", lib, "-e", script,
                      vault_path.to_s, shelf_directory.to_s).first
    end

    before { current_tarvault }

    it "is none when the index has to be published" do
      expect(activated).to eq("")
    end

    it "is none when the index is already published" do
      publication.publish
      expect(activated).to eq("")
    end

    context "when the calling process requires a default gem" do
      let(:preamble) { 'require "zlib"' }

      it "is that gem" do
        expect(activated).to include("zlib")
      end
    end
  end
end

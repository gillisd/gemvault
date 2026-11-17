require "gemvault/static_index"
require "rubygems/package"
require "rubygems/safe_marshal"

RSpec.describe Gemvault::StaticIndex do
  include GemFixtures

  subject(:index) { described_class.new(directory) }

  let(:directory) { gem_dir / "index" }

  def listed(file)
    Gem::SafeMarshal.safe_load(Gem::Util.gunzip((directory / file).binread))
  end

  describe "#published?" do
    it "is false before anything is published" do
      expect(index).not_to be_published
    end

    it "is true once a vault is published" do
      current_tarvault
      open_vault { |vault| index.publish(vault) }
      expect(index).to be_published
    end

    it "is false when gems are stored but the released listing is missing" do
      current_tarvault
      open_vault { |vault| index.publish(vault) }
      (directory / "specs.4.8.gz").delete
      expect(index).not_to be_published
    end
  end

  describe "#url" do
    it "is the file address of the directory" do
      expect(index.url).to eq("file://#{directory}/")
    end
  end

  describe "#publish" do
    before do
      current_tarvault
      open_vault { |vault| index.publish(vault) }
    end

    it "stores each gem file" do
      expect(Gem::Package.new((directory / "gems" / "foo-1.0.0.gem").to_s).spec.name).to eq("foo")
    end

    it "stores each gem's specification" do
      quick = directory / "quick" / "Marshal.4.8" / "foo-1.0.0.gemspec.rz"
      expect(Gem::SafeMarshal.safe_load(Gem::Util.inflate(quick.binread)).full_name).to eq("foo-1.0.0")
    end

    it "lists released gems" do
      expect(listed("specs.4.8.gz")).to eq([["foo", Gem::Version.new("1.0.0"), "ruby"]])
    end

    it "lists released gems as the latest" do
      expect(listed("latest_specs.4.8.gz")).to eq([["foo", Gem::Version.new("1.0.0"), "ruby"]])
    end

    it "lists no prereleases" do
      expect(listed("prerelease_specs.4.8.gz")).to eq([])
    end
  end

  context "when the vault holds two versions of a gem" do
    before do
      tarvault_with(build_gem(name: "foo", version: "1.0.0"), build_gem(name: "foo", version: "2.0.0"))
      open_vault { |vault| index.publish(vault) }
    end

    it "lists only the newest as the latest" do
      expect(listed("latest_specs.4.8.gz")).to eq([["foo", Gem::Version.new("2.0.0"), "ruby"]])
    end

    it "lists both as released" do
      expect(listed("specs.4.8.gz").map { |_, version, _| version.to_s }).to contain_exactly("1.0.0", "2.0.0")
    end
  end

  context "when the vault holds a release and a prerelease of a gem" do
    before do
      tarvault_with(build_gem(name: "foo", version: "1.0.0"), build_gem(name: "foo", version: "2.0.0.rc1"))
      open_vault { |vault| index.publish(vault) }
    end

    it "lists the release as the latest" do
      expect(listed("latest_specs.4.8.gz")).to eq([["foo", Gem::Version.new("1.0.0"), "ruby"]])
    end

    it "lists only the release as released" do
      expect(listed("specs.4.8.gz")).to eq([["foo", Gem::Version.new("1.0.0"), "ruby"]])
    end

    it "lists only the prerelease as a prerelease" do
      expect(listed("prerelease_specs.4.8.gz")).to eq([["foo", Gem::Version.new("2.0.0.rc1"), "ruby"]])
    end
  end

  context "when the vault holds a prerelease" do
    before do
      tarvault_with(build_gem(name: "edge", version: "2.0.0.rc1"))
      open_vault { |vault| index.publish(vault) }
    end

    it "lists it as a prerelease" do
      expect(listed("prerelease_specs.4.8.gz")).to eq([["edge", Gem::Version.new("2.0.0.rc1"), "ruby"]])
    end

    it "keeps it out of the released list" do
      expect(listed("specs.4.8.gz")).to eq([])
    end
  end
end

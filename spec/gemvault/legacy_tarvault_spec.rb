require "gemvault"
require "gemvault/legacy_tarvault"
require "zlib"

RSpec.describe Gemvault::LegacyTarvault do
  subject(:vault) { described_class.new(legacy_tarvault) }

  after { vault.close }

  describe "#format_version" do
    it "is the format the vault was written in" do
      expect(vault.format_version).to eq(2)
    end
  end

  describe "#gem_entries" do
    it "lists every gem the archive holds" do
      expect(vault.gem_entries.map(&:name)).to eq(%w[bar foo])
    end

    it "reads each gem's identity from the gem itself" do
      expect(vault.gem_entries.map(&:version)).to eq(%w[2.0.0 1.0.0])
    end

    it "stamps entries in the notation the current format stores" do
      expect(vault.gem_entries.map(&:created_at)).to all(match(Gemvault::Timestamp::CANONICAL))
    end

    it "gives every gem the same stamp, the index it cannot read having held them" do
      expect(vault.gem_entries.map(&:created_at).uniq.size).to eq(1)
    end
  end

  describe "#size" do
    it "counts the gems without reading their specs" do
      expect(vault.size).to eq(2)
    end
  end

  describe "#gem_data" do
    it "returns the bytes of the gem the entry names" do
      entry = vault.gem_entries.first
      expect(Gem::Package.new(StringIO.new(vault.gem_data(entry))).spec.full_name).to eq(entry.full_name)
    end

    it "raises Vault::NotFoundError for a gem the archive lacks" do
      missing = Gemvault::GemEntry.new(name: "nope", version: "1.0.0")
      expect { vault.gem_data(missing) }.to raise_error(Gemvault::Vault::NotFoundError)
    end
  end

  describe "#specs" do
    it "loads each gemspec from its blob" do
      expect(vault.specs.map(&:name)).to contain_exactly("foo", "bar")
    end
  end

  describe "a stored member that is not a readable gem" do
    subject(:vault) { described_class.new(vault_path) }

    before do
      Gemvault::Tarball.new(vault_path).write(
        [Gemvault::ArchiveEntry.new(name: "manifest.json", bytes: "{}"),
         Gemvault::ArchiveEntry.new(name: "foo-1.0.0.gem", bytes: "not a gem")],
      )
    end

    it "raises Vault::Error naming the vault rather than a tar library's error" do
      expect { vault.gem_entries }.to raise_error(Gemvault::Vault::Error, /Not a valid Tarvault/)
    end
  end

  describe "a stored gem the reader cannot derive an entry from" do
    subject(:vault) { described_class.new(vault_path) }

    before do
      Gemvault::Tarball.new(vault_path).write(
        [Gemvault::ArchiveEntry.new(name: "manifest.json", bytes: "{}"),
         Gemvault::ArchiveEntry.new(name: "foo-1.0.0.gem", bytes: gem_bytes)],
      )
    end

    context "when its compressed metadata stream is corrupt" do
      let(:gem_bytes) { gem_with_corrupt_metadata_stream }

      it "raises Vault::Error naming the vault rather than a compression library's error" do
        expect { vault.gem_entries }.to raise_error(Gemvault::Vault::Error, /Not a valid Tarvault/)
      end
    end

    context "when its metadata is not YAML" do
      let(:gem_bytes) { gem_with_metadata(Zlib.gzip("not: valid: yaml: [")) }

      it "raises Vault::Error naming the vault rather than a YAML parser's error" do
        expect { vault.gem_entries }.to raise_error(Gemvault::Vault::Error, /Not a valid Tarvault/)
      end
    end

    context "when its metadata is YAML but not a gemspec" do
      let(:gem_bytes) { gem_with_metadata(Zlib.gzip("--- {}\n")) }

      it "raises Vault::Error naming the vault rather than rubygems' error" do
        expect { vault.gem_entries }.to raise_error(Gemvault::Vault::Error, /Not a valid Tarvault/)
      end
    end
  end

  describe "writing" do
    it "refuses add, pointing at upgrade" do
      expect { vault.add("x.gem") }.to raise_error(Gemvault::Vault::ReadOnlyError, /upgrade/)
    end

    it "refuses remove, pointing at upgrade" do
      expect { vault.remove("foo") }.to raise_error(Gemvault::Vault::ReadOnlyError, /upgrade/)
    end
  end

  describe "opening" do
    it "warns that the format is read-only" do
      output = StringIO.new
      Gemvault::Deprecation.output = output
      described_class.new(legacy_tarvault).close
      expect(output.string).to include("read-only")
    end

    it "raises Vault::NotFoundError for a missing file" do
      expect { described_class.new(gem_dir / "nope.gemv") }.to raise_error(Gemvault::Vault::NotFoundError)
    end
  end

  def gem_with_corrupt_metadata_stream
    bytes = File.binread(build_gem(name: "foo", version: "1.0.0"))
    stream = bytes.index("metadata.gz") + 512 + 10
    20.times { |offset| bytes.setbyte(stream + offset, 0xFF) }
    bytes
  end

  def gem_with_metadata(compressed)
    source = build_gem(name: "foo", version: "1.0.0")
    rebuilt = source.sub_ext(".rebuilt.gem")
    Gemvault::Tarball.new(rebuilt).write(metadata_swapped(Gemvault::Tarball.new(source).entries, compressed))
    File.binread(rebuilt)
  end

  def metadata_swapped(entries, compressed)
    entries.map do |entry|
      entry.name == "metadata.gz" ? Gemvault::ArchiveEntry.new(name: "metadata.gz", bytes: compressed) : entry
    end
  end
end

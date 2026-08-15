require "gemvault/tarvault"

RSpec.describe "Gemvault::Tarvault reading" do
  describe "#gem_data", :aggregate_failures do
    it "returns the exact stored bytes" do
      original = File.binread(foo_gem)
      tarvault_with(foo_gem)
      reopen_tarvault { |v| expect(v.gem_data(foo_entry)).to eq(original) }
    end

    it "raises Vault::NotFoundError for a missing gem" do
      create_tarvault do |v|
        expect { v.gem_data(foo_entry) }.to raise_error(Gemvault::Vault::NotFoundError)
      end
    end

    it "raises Vault::Error when the stored blob fails its checksum" do
      tarvault_with(foo_gem)
      corrupt_gem_blob(vault_path)
      reopen_tarvault { |v| expect { v.gem_data(foo_entry) }.to raise_error(Gemvault::Vault::Error, /[Ii]ntegrity/) }
    end
  end

  describe "a vault whose manifest gemvault did not write" do
    def vault_holding(manifest)
      Gemvault::Tarball.new(vault_path).write([Gemvault::ArchiveEntry.new(name: "manifest", bytes: manifest)])
    end

    it "raises Vault::Error naming the vault when the manifest is malformed" do
      vault_holding("gemvault 3\nnot a manifest\n")
      expect { reopen_tarvault { |v| v } }.to raise_error(Gemvault::Vault::Error, /Not a valid Tarvault/)
    end
  end

  describe "#gem_entries / #specs" do
    it "lists entries as GemEntry objects" do
      tarvault_with(foo_gem)
      reopen_tarvault { |v| expect(v.gem_entries.first).to be_a(Gemvault::GemEntry) }
    end

    it "loads gemspecs including dependencies and platform" do
      tarvault_with(build_gem(name: "dep", version: "1.0.0", dependencies: [["rake", ">= 13.0"]]))
      reopen_tarvault { |v| expect(v.specs.first.dependencies.map(&:name)).to include("rake") }
    end
  end

  describe "GemExtraction" do
    it "yields a real .gem file path from #with_gem_file and unlinks it after" do
      tarvault_with(foo_gem)
      captured = nil
      reopen_tarvault { |v| v.with_gem_file(foo_entry) { |p| captured = p } }
      expect(File.exist?(captured)).to be(false)
    end
  end
end

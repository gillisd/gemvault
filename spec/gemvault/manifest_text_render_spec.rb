require "gemvault/manifest_text"

RSpec.describe Gemvault::ManifestText, ".render" do
  include_context "with a stored foo record"

  subject(:document) { described_class.render(one_record_manifest) }

  it "opens with a magic line naming the format version" do
    expect(document.lines.first).to eq("gemvault 3\n")
  end

  it "records the vault's creation time" do
    expect(document.lines[1]).to eq("created #{stamp}\n")
  end

  it "separates the header from the records with a blank line" do
    expect(document.lines[2]).to eq("\n")
  end

  it "writes one line per stored gem" do
    expect(document.lines[3]).to eq("foo 1.0.0 ruby #{stamp} #{digest} 0\n")
  end

  it "writes no line for a vault holding no gems" do
    expect(described_class.render(empty_manifest).lines.size).to eq(3)
  end

  it "ends with a newline" do
    expect(document).to end_with("\n")
  end

  it "writes the encrypted flag as 1" do
    encrypted = Gemvault::Manifest::StoredGem.new(gem: entry, sha256: digest, encrypted: true)
    expect(described_class.render(empty_manifest.with_record(encrypted)).lines[3]).to end_with(" 1\n")
  end

  it "writes a platform-specific gem's platform" do
    native = Gemvault::GemEntry.new(name: "foo", version: "1.0.0", platform: "aarch64-linux", created_at: stamp)
    stored = Gemvault::Manifest::StoredGem.new(gem: native, sha256: digest, encrypted: false)
    expect(described_class.render(empty_manifest.with_record(stored)).lines[3])
      .to eq("foo 1.0.0 aarch64-linux #{stamp} #{digest} 0\n")
  end

  it "writes text that carries no character needing an escape" do
    expect(document).to match(/\A[\x20-\x7e\n]+\z/)
  end
end

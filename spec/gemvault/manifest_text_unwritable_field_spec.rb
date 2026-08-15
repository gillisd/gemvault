require "gemvault/manifest_text"

RSpec.describe Gemvault::ManifestText, ".unwritable_field" do
  def entry(name: "foo", version: "1.0.0", platform: "ruby")
    Gemvault::GemEntry.new(name:, version:, platform:, created_at: "2026-07-11T00:00:00Z")
  end

  it "returns nil for an entry every field alphabet accepts" do
    expect(described_class.unwritable_field(entry)).to be_nil
  end

  it "returns :name for a name holding a space" do
    expect(described_class.unwritable_field(entry(name: "foo bar"))).to eq(:name)
  end

  it "returns :version for an empty version" do
    expect(described_class.unwritable_field(entry(version: ""))).to eq(:version)
  end

  it "returns :platform for a platform holding a space" do
    expect(described_class.unwritable_field(entry(platform: "weird platform"))).to eq(:platform)
  end
end

require "json"
require "gemvault/json"

RSpec.describe Gemvault::Json, ".pretty_generate" do
  let(:manifest_shaped) do
    {
      vault_version: 2,
      format: "tarvault",
      created_at: 1_754_745_600,
      gems: [
        { name: "foo", version: "1.0.0", platform: "ruby", created_at: 1_754_745_600,
          sha256: "ab" * 32, encrypted: false },
      ],
    }
  end

  it "matches the json gem's pretty output for a manifest" do
    expect(described_class.pretty_generate(manifest_shaped)).to eq(JSON.pretty_generate(manifest_shaped))
  end

  it "matches the json gem's pretty output for empty containers" do
    value = { gems: [], meta: {} }
    expect(described_class.pretty_generate(value)).to eq(JSON.pretty_generate(value))
  end

  it "matches the json gem's escaping" do
    value = { note: %(a "quoted" \\ backslash\nnewline\ttab café) }
    expect(described_class.pretty_generate(value)).to eq(JSON.pretty_generate(value))
  end

  it "matches the json gem for null, true, false and floats" do
    value = { a: nil, b: true, c: false, d: 1.5 }
    expect(described_class.pretty_generate(value)).to eq(JSON.pretty_generate(value))
  end

  it "round-trips through its own parse" do
    expect(described_class.parse(described_class.pretty_generate(manifest_shaped))).to eq(manifest_shaped)
  end
end

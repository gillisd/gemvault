require "gemvault/archive_entry"

RSpec.describe Gemvault::ArchiveEntry do
  it "carries a name and its bytes", :aggregate_failures do
    entry = described_class.new(name: "foo-1.0.0.gem", bytes: "BINARY")
    expect(entry.name).to eq("foo-1.0.0.gem")
    expect(entry.bytes).to eq("BINARY")
  end

  it "is equal to another entry with the same name and bytes" do
    entry = described_class.new(name: "a", bytes: "x")
    twin = described_class.new(name: "a", bytes: "x")
    expect(entry).to eq(twin)
  end
end

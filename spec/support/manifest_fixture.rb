RSpec.shared_context "with a stored foo record" do
  let(:entry) do
    Gemvault::GemEntry.new(
      name: "foo", version: "1.0.0", platform: "ruby", created_at: "2026-07-11 00:00:00",
    )
  end

  let(:record) do
    Gemvault::Manifest::StoredGem.new(gem: entry, sha256: "abc", encrypted: false)
  end

  let(:empty_manifest) { Gemvault::Manifest.empty(created_at: "t") }

  let(:one_record_manifest) { empty_manifest.with_record(record) }
end

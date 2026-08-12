RSpec.shared_context "with a stored foo record" do
  let(:stamp) { "2026-07-11T00:00:00Z" }

  let(:digest) { "ab" * 32 }

  let(:entry) do
    Gemvault::GemEntry.new(name: "foo", version: "1.0.0", platform: "ruby", created_at: stamp)
  end

  let(:record) do
    Gemvault::Manifest::StoredGem.new(gem: entry, sha256: digest, encrypted: false)
  end

  let(:empty_manifest) { Gemvault::Manifest.empty(created_at: stamp) }

  let(:one_record_manifest) { empty_manifest.with_record(record) }
end

RSpec.shared_context "with a two-entry tarball" do
  let(:path) { gem_dir / "a.tar" }
  let(:archive) { Gemvault::Tarball.new(path) }
  let(:blob) { "BINARY#{0.chr}DATA" }
  let(:entries) do
    [
      Gemvault::ArchiveEntry.new(name: "manifest", bytes: "x"),
      Gemvault::ArchiveEntry.new(name: "foo-1.0.0.gem", bytes: blob),
    ]
  end
end

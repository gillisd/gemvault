require "gemvault/tarvault"

RSpec.describe "Gemvault::Tarvault lifecycle", :aggregate_failures do
  it "creates an empty vault whose manifest is the first tar entry" do
    create_tarvault { |v| expect(v.size).to eq(0) }
    expect(first_tar_entry_name(vault_path)).to eq("manifest")
  end

  it "raises Vault::Error when creating over an existing file" do
    Gemvault::Tarvault.new(vault_path, create: true)
    expect { Gemvault::Tarvault.new(vault_path, create: true) }.to raise_error(Gemvault::Vault::Error)
  end

  it "raises Vault::NotFoundError when opening a missing file" do
    expect { Gemvault::Tarvault.new(gem_dir / "nope.gemv") }.to raise_error(Gemvault::Vault::NotFoundError)
  end

  it "raises Vault::Error when opening a file that is not a tar" do
    (gem_dir / "bad.gemv").write("this is not a tar")
    expect { Gemvault::Tarvault.new(gem_dir / "bad.gemv") }.to raise_error(Gemvault::Vault::Error)
  end

  it "treats a tar holding only the legacy manifest.json as missing its manifest" do
    Gemvault::Tarball.new(vault_path).write([Gemvault::ArchiveEntry.new(name: "manifest.json", bytes: "{}")])
    expect { Gemvault::Tarvault.new(vault_path) }
      .to raise_error(Gemvault::Vault::Error, /missing manifest/)
  end

  it "reopens and preserves data" do
    tarvault_with(foo_gem)
    reopen_tarvault { |v| expect(v.size).to eq(1) }
  end
end

require "gemvault/tarvault"

RSpec.describe "Gemvault::Tarvault#add" do
  it "stores a gem and increments size" do
    create_tarvault { |v| expect { v.add(foo_gem) }.to change { v.size }.from(0).to(1) }
  end

  it "preserves a supplied created_at" do
    create_tarvault do |v|
      v.add(foo_gem, created_at: "2000-01-01 00:00:00")
      expect(v.gem_entries.first.created_at).to eq("2000-01-01 00:00:00")
    end
  end

  it "raises Vault::NotFoundError for a missing gem file" do
    create_tarvault { |v| expect { v.add(gem_dir / "nope.gem") }.to raise_error(Gemvault::Vault::NotFoundError) }
  end

  it "raises Vault::InvalidGemError for a non-gem file" do
    (gem_dir / "bad.gem").write("not a gem")
    create_tarvault { |v| expect { v.add(gem_dir / "bad.gem") }.to raise_error(Gemvault::Vault::InvalidGemError) }
  end

  it "raises Vault::DuplicateGemError on the same name/version/platform" do
    tarvault_with(foo_gem) do |v|
      expect { v.add(foo_gem) }.to raise_error(Gemvault::Vault::DuplicateGemError)
    end
  end

  it "stores a platform-specific gem under its platform filename" do
    tarvault_with(build_gem(name: "native", version: "1.0.0", platform: "x86_64-linux"))
    reopen_tarvault { |v| expect(v.gem_entries.first.filename).to eq("native-1.0.0-x86_64-linux.gem") }
  end

  it "re-adds a gem after it was removed" do
    tarvault_with(foo_gem) do |v|
      v.remove(foo_reference)
      expect { v.add(foo_gem) }.to change { v.size }.from(0).to(1)
    end
  end
end

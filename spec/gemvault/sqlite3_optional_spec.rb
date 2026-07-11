require "gemvault"

RSpec.describe "sqlite3 as an optional dependency" do
  def sqlite3_state_after_tarvault(path)
    script = <<~RUBY
      require "gemvault"
      Gemvault::Vault.open(#{path.inspect}, create: true) { |v| v }
      Gemvault::Vault.open(#{path.inspect}) { |v| v.size }
      print defined?(SQLite3) ? "loaded" : "absent"
    RUBY
    IO.popen(["ruby", "-Ilib", "-e", script], &:read)
  end

  it "loads and uses a tarvault without loading sqlite3" do
    expect(sqlite3_state_after_tarvault(vault_path.to_s)).to eq("absent")
  end

  it "raises a helpful error opening a legacy Dbvault when sqlite3 is unavailable" do
    legacy_dbvault
    allow(Gemvault::Vault).to receive(:require_relative).with("dbvault")
                                                        .and_raise(LoadError.new("cannot load such file -- sqlite3"))
    expect { Gemvault::Vault.open(vault_path) { |v| v } }.to raise_error(Gemvault::Vault::Error, /sqlite3/)
  end
end

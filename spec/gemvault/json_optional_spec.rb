require "gemvault"

RSpec.describe "json as a gem gemvault never loads" do
  def json_state_after_tarvault(path)
    script = <<~RUBY
      require "gemvault"
      require "bundler/plugin/vault_source" rescue nil
      Gemvault::Vault.open(#{path.inspect}, create: true) { |v| v }
      Gemvault::Vault.open(#{path.inspect}) { |v| v.size }
      print defined?(JSON) ? "loaded" : "absent"
    RUBY
    IO.popen(["ruby", "-Ilib", "-e", script], &:read)
  end

  it "reads and writes a tarvault without loading the json gem" do
    expect(json_state_after_tarvault(vault_path.to_s)).to eq("absent")
  end
end

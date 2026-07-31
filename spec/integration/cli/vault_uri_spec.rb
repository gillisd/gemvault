RSpec.describe "gemvault commands with URI vault locators", :integration do
  it "lists gems through a vault:/// URI" do
    expect(list_vault_through_uri("vault://")).to succeed_showing("uri_gem-1.0.0")
  end

  it "lists gems through a file:/// URI" do
    expect(list_vault_through_uri("file://")).to succeed_showing("uri_gem-1.0.0")
  end

  it "upgrades through a vault:/// URI" do
    expect(upgrade_vault_through_uri("vault://")).to succeed_showing("already current")
  end
end

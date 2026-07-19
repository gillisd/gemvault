RSpec.describe "gemvault commands with URI vault locators", :integration do
  it "lists gems through a vault:/// URI", :aggregate_failures do
    output, status = list_vault_through_uri("vault://")
    expect(status).to be_success, "gemvault list failed:\n#{output}"
    expect(output).to include("uri_gem-1.0.0")
  end

  it "lists gems through a file:/// URI", :aggregate_failures do
    output, status = list_vault_through_uri("file://")
    expect(status).to be_success, "gemvault list failed:\n#{output}"
    expect(output).to include("uri_gem-1.0.0")
  end
end

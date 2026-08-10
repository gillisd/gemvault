RSpec.describe "bundler/inline with vault source", :integration do
  it "discovers the vault plugin and installs the gem" do
    expect(run_inline_install).to succeed_showing("1.0.0")
  end

  context "when the inline gemfile does not force installation" do
    it "still makes the vault gem requireable" do
      expect(run_inline_install_without_force).to succeed_showing("1.0.0")
    end
  end

  context "when RubyGems discovers the vault plugin twice under Bundler" do
    it "loads it without redefining its constants" do
      output, = run_inline_install
      expect(output).not_to include("already initialized constant")
    end
  end
end

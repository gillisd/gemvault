RSpec.describe "bundle install with gemvault bundled from a path", :integration do
  context "when the user has no gemvault installed outside the project" do
    it "installs command_kit from the local index" do
      expect(path_bundled_install).to succeed_showing("Installing command_kit")
    end

    it "completes the bundle" do
      expect(path_bundled_install).to succeed_showing("Bundle complete!")
    end

    it "loads the tree's RubyGems plugin quietly" do
      expect(path_bundled_install).to succeed.without("Error loading RubyGems plugin")
    end
  end
end

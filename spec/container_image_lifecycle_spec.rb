RSpec.describe "ContainerImage lifecycle" do
  include_context "with a stubbed container shell"

  let(:rmi_command) { ["podman", "rmi", image_name] }

  describe "#exists?" do
    it "is true when podman finds the image" do
      shell_runs(true)
      expect(image.exists?).to be(true)
    end

    it "is false when podman does not find the image" do
      shell_runs(false)
      expect(image.exists?).to be(false)
    end

    it "silences podman rather than reporting a missing image as an error" do
      shell_runs(true)
      image.exists?
      expect(shell).to have_received(:run).with("podman", "image", "exists", image_name, silent: true)
    end
  end

  describe "#ensure_built" do
    it "builds when the image is absent" do
      shell_runs(false, true)
      image.ensure_built
      expect(shell).to have_received(:run).with(*build_command)
    end

    it "does not build when the image is already present" do
      shell_runs(true)
      image.ensure_built
      expect(shell).not_to have_received(:run).with(*build_command)
    end
  end
end

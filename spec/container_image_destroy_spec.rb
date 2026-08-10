RSpec.describe "ContainerImage#destroy" do
  include_context "with a stubbed container shell"

  let(:rmi_command) { ["podman", "rmi", image_name] }
  let(:strays) { "" }

  before { allow(shell).to receive_messages(run: true, capture: strays) }

  it "removes the image" do
    image.destroy
    expect(shell).to have_received(:run).with(*rmi_command)
  end

  it "asks podman which containers came from the image" do
    image.destroy
    expect(shell).to have_received(:capture).with("podman", "ps", "-aq", "--filter", "ancestor=#{image_name}")
  end

  context "when containers from the image are still around" do
    let(:strays) { "aaa\nbbb\n" }

    it "removes them" do
      image.destroy
      expect(shell).to have_received(:run).with("podman", "rm", "-f", "aaa", "bbb")
    end

    it "removes them before the image", :aggregate_failures do
      image.destroy
      expect(shell).to have_received(:run).with("podman", "rm", "-f", "aaa", "bbb").ordered
      expect(shell).to have_received(:run).with(*rmi_command).ordered
    end
  end

  context "when no containers came from the image" do
    it "removes no containers" do
      image.destroy
      expect(shell).not_to have_received(:run).with("podman", "rm", "-f")
    end
  end

  it "raises when the image cannot be removed" do
    allow(shell).to receive(:run).with(*rmi_command).and_return(false)
    expect { image.destroy }.to raise_error(ContainerImage::Error, /gemvault-test:latest/)
  end

  context "when the image was never built" do
    before { shell_runs(false) }

    it "removes nothing" do
      image.destroy
      expect(shell).not_to have_received(:run).with(*rmi_command)
    end

    it "does not ask podman for containers" do
      image.destroy
      expect(shell).not_to have_received(:capture)
    end
  end
end

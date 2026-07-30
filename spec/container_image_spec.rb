RSpec.describe ContainerImage do
  subject(:image) do
    described_class.new(name: image_name, root: "/src/root", digest: "abc123", shell: shell, log: log)
  end

  let(:image_name) { "gemvault-test:latest" }
  let(:shell) { instance_double(Shell) }
  let(:log) { StringIO.new }

  let(:build_command) do
    ["podman", "build", "--network=host", "-v", "/src/root:/src:ro,z",
     "--build-arg", "SOURCE_DIGEST=abc123",
     "-t", "gemvault-test:latest", "-f", "Dockerfile.test", "."]
  end

  describe "#build" do
    it "passes the bind mount, digest, tag and dockerfile to podman" do
      allow(shell).to receive(:run).and_return(true)
      image.build
      expect(shell).to have_received(:run).with(*build_command)
    end

    it "echoes the command it runs" do
      allow(shell).to receive(:run).and_return(true)
      image.build
      expect(log.string).to include("podman build --network=host")
    end

    it "attempts the build once when it succeeds" do
      allow(shell).to receive(:run).and_return(true)
      image.build
      expect(shell).to have_received(:run).once
    end

    it "succeeds when a later attempt succeeds" do
      allow(shell).to receive(:run).and_return(false, true)
      expect(image.build).to be(true)
    end

    it "makes no further attempts once one succeeds" do
      allow(shell).to receive(:run).and_return(false, true)
      image.build
      expect(shell).to have_received(:run).twice
    end

    it "announces every retry" do
      allow(shell).to receive(:run).and_return(false, false, true)
      image.build
      expect(log.string.lines.grep(/retrying/).size).to eq(2)
    end

    it "raises when every attempt fails" do
      allow(shell).to receive(:run).and_return(false)
      expect { image.build }.to raise_error(ContainerImage::Error, /after 3 attempts/)
    end

    it "names the image it gave up on" do
      allow(shell).to receive(:run).and_return(false)
      expect { image.build }.to raise_error(/gemvault-test:latest/)
    end

    it "exhausts every allowed attempt before raising", :aggregate_failures do
      allow(shell).to receive(:run).and_return(false)
      expect { image.build }.to raise_error(ContainerImage::Error)
      expect(shell).to have_received(:run).exactly(3).times
    end
  end

  describe "#exists?" do
    it "is true when podman finds the image" do
      allow(shell).to receive(:run).and_return(true)
      expect(image.exists?).to be(true)
    end

    it "is false when podman does not find the image" do
      allow(shell).to receive(:run).and_return(false)
      expect(image.exists?).to be(false)
    end

    it "silences podman rather than reporting a missing image as an error" do
      allow(shell).to receive(:run).and_return(true)
      image.exists?
      expect(shell).to have_received(:run).with("podman", "image", "exists", image_name, silent: true)
    end
  end

  describe "#ensure_built" do
    it "builds when the image is absent" do
      allow(shell).to receive(:run).and_return(false, true)
      image.ensure_built
      expect(shell).to have_received(:run).with(*build_command)
    end

    it "does not build when the image is already present" do
      allow(shell).to receive(:run).and_return(true)
      image.ensure_built
      expect(shell).not_to have_received(:run).with(*build_command)
    end
  end

  describe "#destroy" do
    before { allow(shell).to receive_messages(run: true, capture: strays) }

    let(:strays) { "" }

    it "removes the image" do
      image.destroy
      expect(shell).to have_received(:run).with("podman", "rmi", image_name)
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
        expect(shell).to have_received(:run).with("podman", "rmi", image_name).ordered
      end
    end

    context "when no containers came from the image" do
      it "removes no containers" do
        image.destroy
        expect(shell).not_to have_received(:run).with("podman", "rm", "-f")
      end
    end

    it "raises when the image cannot be removed" do
      allow(shell).to receive(:run).with("podman", "rmi", image_name).and_return(false)
      expect { image.destroy }.to raise_error(ContainerImage::Error, /gemvault-test:latest/)
    end

    context "when the image was never built" do
      before { allow(shell).to receive(:run).and_return(false) }

      it "removes nothing" do
        image.destroy
        expect(shell).not_to have_received(:run).with("podman", "rmi", image_name)
      end

      it "does not ask podman for containers" do
        image.destroy
        expect(shell).not_to have_received(:capture)
      end
    end
  end
end

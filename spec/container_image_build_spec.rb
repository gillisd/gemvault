RSpec.describe "ContainerImage#build" do
  include_context "with a stubbed container shell"

  context "when the first attempt succeeds" do
    before { shell_runs(true) }

    it "passes the bind mount, digest, tag and dockerfile to podman" do
      image.build
      expect(shell).to have_received(:run).with(*build_command)
    end

    it "echoes the command it runs" do
      image.build
      expect(log.string).to include("podman build --network=host")
    end

    it "attempts the build once" do
      image.build
      expect(shell).to have_received(:run).once
    end
  end

  context "when only the second attempt succeeds" do
    before { shell_runs(false, true) }

    it "succeeds" do
      expect(image.build).to be(true)
    end

    it "makes no further attempts once one succeeds" do
      image.build
      expect(shell).to have_received(:run).twice
    end
  end

  context "when only the last allowed attempt succeeds" do
    before { shell_runs(false, false, true) }

    it "announces every retry" do
      image.build
      expect(log.string.lines.grep(/retrying/).size).to eq(2)
    end
  end

  context "when every attempt fails" do
    before { shell_runs(false) }

    it "raises" do
      expect { image.build }.to raise_error(ContainerImage::Error, /after 3 attempts/)
    end

    it "names the image it gave up on" do
      expect { image.build }.to raise_error(/gemvault-test:latest/)
    end

    it "exhausts every allowed attempt before raising", :aggregate_failures do
      expect { image.build }.to raise_error(ContainerImage::Error)
      expect(shell).to have_received(:run).exactly(3).times
    end
  end
end

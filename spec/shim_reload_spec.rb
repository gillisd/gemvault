require "fileutils"
require "open3"

RSpec.describe "the shim's load path resolution under repeated evaluation" do
  let(:copies) { %w[older newer].map { |name| gem_dir / name / "gemvault_load_path.rb" } }

  def install_copies
    copies.each do |copy|
      copy.dirname.mkpath
      FileUtils.cp(File.expand_path("../shim/gemvault_load_path.rb", __dir__), copy)
    end
  end

  def load_both
    Open3.capture2e(RbConfig.ruby, "-e", copies.map { |copy| "load #{copy.to_s.inspect}" }.join(";")).first
  end

  it "tolerates loading from two installed copies without redefinition warnings" do
    install_copies

    expect(load_both).to eq("")
  end
end

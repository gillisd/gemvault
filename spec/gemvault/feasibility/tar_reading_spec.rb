require "rubygems/package"
require "stringio"

RSpec.describe "reading gemspecs from a plain tar of .gem files" do
  let(:tar_path) { gem_dir / "plain.tar" }

  before do
    a = File.binread(build_gem("alpha", "1.0.0"))
    b = File.binread(build_gem("beta", "2.0.0"))
    Gem::Package::TarWriter.new(File.open(tar_path, "wb")) do |w|
      { "alpha-1.0.0.gem" => a, "beta-2.0.0.gem" => b }.each do |name, bytes|
        w.add_file_simple(name, 0o644, bytes.bytesize) { |io| io.write(bytes) }
      end
    end
  end

  it "extracts every spec when read eagerly inside the iteration" do
    names = []
    Gem::Package::TarReader.new(File.open(tar_path, "rb")) do |r|
      r.each_entry { |e| names << Gem::Package.new(StringIO.new(e.read)).spec.full_name }
    end
    expect(names).to contain_exactly("alpha-1.0.0", "beta-2.0.0")
  end

  it "raises IOError if a tar entry is read after iteration closes it" do
    stashed = []
    Gem::Package::TarReader.new(File.open(tar_path, "rb")) { |r| r.each_entry { |e| stashed << e } }
    expect { stashed.first.read }.to raise_error(IOError)
  end
end

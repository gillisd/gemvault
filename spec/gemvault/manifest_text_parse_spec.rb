require "gemvault/manifest_text"

RSpec.describe Gemvault::ManifestText, ".parse" do
  include_context "with a stored foo record"

  let(:document) { "gemvault 3\ncreated #{stamp}\n\nfoo 1.0.0 ruby #{stamp} #{digest} 0\n" }

  def parse(text) = described_class.parse(text)

  it "reads the declared format version" do
    expect(parse(document).format_version).to eq(3)
  end

  it "reads the vault's creation time" do
    expect(parse(document).created_at).to eq(stamp)
  end

  it "reads each stored gem" do
    expect(parse(document).records).to eq([record])
  end

  it "reads a vault holding no gems" do
    expect(parse("gemvault 3\ncreated #{stamp}\n\n").records).to eq([])
  end

  it "reads the encrypted flag" do
    encrypted = document.sub(" 0\n", " 1\n")
    expect(parse(encrypted).records.first.encrypted).to be(true)
  end

  it "reads a version the running gemvault does not write" do
    expect(parse(document.sub("gemvault 3", "gemvault 9")).format_version).to eq(9)
  end

  it "round-trips what render writes" do
    expect(parse(described_class.render(one_record_manifest))).to eq(one_record_manifest)
  end

  context "when the document is not one gemvault wrote" do
    it "rejects an empty document" do
      expect { parse("") }.to raise_error(described_class::MalformedError)
    end

    it "rejects a missing magic line" do
      expect { parse("created #{stamp}\n\n") }.to raise_error(described_class::MalformedError)
    end

    it "rejects a non-numeric format version" do
      expect { parse(document.sub("gemvault 3", "gemvault three")) }.to raise_error(described_class::MalformedError)
    end

    it "rejects a missing header separator" do
      expect { parse("gemvault 3\ncreated #{stamp}\nfoo 1.0.0 ruby #{stamp} #{digest} 0\n") }
        .to raise_error(described_class::MalformedError)
    end

    it "rejects a blank line among the records" do
      expect { parse("#{document}\nfoo 2.0.0 ruby #{stamp} #{digest} 0\n") }
        .to raise_error(described_class::MalformedError)
    end

    it "rejects a record missing a field" do
      expect { parse(document.sub(" #{digest} 0\n", " 0\n")) }.to raise_error(described_class::MalformedError)
    end

    it "rejects a record carrying an extra field" do
      expect { parse(document.sub(" 0\n", " 0 extra\n")) }.to raise_error(described_class::MalformedError)
    end

    it "rejects a digest that is not 64 hex characters" do
      expect { parse(document.sub(digest, "abc")) }.to raise_error(described_class::MalformedError)
    end

    it "rejects a timestamp in the legacy notation" do
      expect { parse(document.sub(/ #{stamp} #{digest}/, " 2000-01-01 00:00:00 #{digest}")) }
        .to raise_error(described_class::MalformedError)
    end

    it "rejects an encrypted flag that is neither 0 nor 1" do
      expect { parse(document.sub(" 0\n", " yes\n")) }.to raise_error(described_class::MalformedError)
    end

    it "rejects a gem name outside rubygems' alphabet" do
      expect { parse(document.sub("foo 1.0.0", "foo/../etc 1.0.0")) }
        .to raise_error(described_class::MalformedError)
    end

    it "rejects JSON, the notation gemvault used to write" do
      expect { parse(%({"vault_version":2,"gems":[]})) }.to raise_error(described_class::MalformedError)
    end

    it "names the line it rejected" do
      expect { parse(document.sub(" 0\n", " yes\n")) }.to raise_error(/foo 1\.0\.0/)
    end

    it "rejects a pathological document without exhausting the stack" do
      expect { parse("gemvault 3\ncreated #{stamp}\n\n#{"[" * 200_000}\n") }
        .to raise_error(described_class::MalformedError)
    end
  end
end

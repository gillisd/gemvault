# Builds the working tree's gemvault and bundler-source-vault gems inside the
# container, from the read-only /gem mount, into /work/src.
module TreeGems
  def self.build_preamble
    <<~SH
      set -e
      mkdir -p /work/src
      cp -r /gem/lib /gem/exe /gem/shim /gem/gemvault.gemspec /gem/README.md /gem/LICENSE.txt /gem/Rakefile /work/src/
      (cd /work/src && gem build -q gemvault.gemspec >/dev/null)
      (cd /work/src/shim && gem build -q bundler-source-vault.gemspec >/dev/null)
    SH
  end
end

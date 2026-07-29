# The Gemfile a vaulted project has, as distinct from what the user does to it.
module VaultedGemfile
  def self.declaring(vaulted: [], second_vault: [], rubygems: [], own_gemspec: false)
    <<~SH
      #{project_gemspec if own_gemspec}
      cat > Gemfile <<GEMFILE
      #{GemIndex.source_line}
      #{"gemspec" if own_gemspec}
      #{rubygems.map { |name| %(gem "#{name}") }.join("\n")}
      #{vault_block("$WORKDIR/test.gemv", vaulted)}
      #{vault_block("$WORKDIR/#{VaultedProject::SECOND_VAULT}.gemv", second_vault)}
      GEMFILE
    SH
  end

  # The reporter's Gemfile carries `gemspec` beside its vault source, which adds
  # a path source for the project's own gem, and a rubygems dependency through
  # it. That puts three source kinds in one Gemfile.
  def self.project_gemspec
    name = VaultedProject::OWN_GEM

    <<~SH
      mkdir -p $WORKDIR/lib
      echo 'module #{VaultedProject::OWN_GEM_CONSTANT}; end' > $WORKDIR/lib/#{name}.rb
      cat > $WORKDIR/#{name}.gemspec <<'GEMSPEC'
      #{gemspec_body(name)}
      GEMSPEC
    SH
  end

  def self.gemspec_body(name)
    <<~GEMSPEC.chomp
      Gem::Specification.new do |s|
        s.name = "#{name}"
        s.version = "0.1.0"
        s.summary = "the project's own gem"
        s.authors = ["test"]
        s.license = "MIT"
        s.homepage = "https://example.com"
        s.files = ["lib/#{name}.rb"]
        s.add_dependency "#{VaultedProject::RUBYGEMS_GEM}"
      end
    GEMSPEC
  end

  def self.vault_block(vault, gems)
    return "" if gems.empty?

    declarations = gems.map { |name| %(  gem "#{name}") }.join("\n")

    "source \"#{vault}\", type: :vault do\n#{declarations}\nend"
  end
end

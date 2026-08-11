require "pathname"

module Gemvault
  ##
  # A gem installation record -- <tt>specifications/<full name>.gemspec</tt> --
  # whose <tt>gems/<full name></tt> directory is gone: the wreckage of an
  # interrupted uninstall or a hand-cleaned gem home.
  #
  # RubyGems still lists such a gem as installed, and Bundler's Gemfile-driven
  # plugin installer trusts that record: it materializes the plugin against the
  # ambient gem roots, reinstalls the missing gem into the plugin root, but
  # then validates <tt>plugins.rb</tt> against the ghost's dead directory
  # instead of the copy it just extracted. Every <tt>bundle install</tt> after
  # that dies with <tt>MalformattedPlugin (plugins.rb was not found in the
  # plugin.)</tt> -- issue #23. Removing the ghost record lets the next install
  # see the machine as it really is.
  #
  # Detection never evaluates the record. The gem directory's name is the
  # record's file name minus <tt>.gemspec</tt> by RubyGems' own install
  # convention, so a missing payload is recognized from the filesystem alone --
  # which lets a truncated or unreadable record, wreckage in its own right, be
  # swept rather than silently skipped. Scoping to the asked gem reads the
  # record's "# stub:" header when it is readable and falls back to the
  # filename when it is not.
  #
  # Deliberately out of scope: a gem directory that exists but has lost part of
  # its payload. Telling that wreck apart from a healthy install would mean
  # trusting the record's file list, and a false positive here deletes a
  # working installation's record.
  class GhostSpecification
    # All ghost specifications of +name+ across +roots+ (gem homes as listed
    # on Gem.path, the same view Bundler's plugin installer resolves against).
    def self.of(name, roots: Gem.path)
      roots.flat_map { |root| in_root(Pathname(root), name) }
    end

    def self.in_root(root, name)
      root.join("specifications").glob("#{name}-*.gemspec")
          .select { |file| of_gem?(file, name) }
          .reject { |file| root.join("gems", file.basename(".gemspec").to_s).directory? }
          .map { |file| new(file) }
    end
    private_class_method :in_root

    def self.of_gem?(file, name)
      stub_name = stub_header_name(file)
      return stub_name == name unless stub_name.nil?

      version_shaped?(file.basename(".gemspec").to_s.delete_prefix("#{name}-"))
    end
    private_class_method :of_gem?

    # Installed records open with an optional encoding magic comment followed
    # by "# stub: <name> <version> <platform> <require paths>".
    def self.stub_header_name(file)
      file.open("r") do |io|
        2.times do
          line = io.gets or break
          name = line[/\A# stub: (\S+) /, 1] and return name
        end
      end
      nil
    rescue SystemCallError
      nil
    end
    private_class_method :stub_header_name

    # A version starts with a digit and a gem-name segment rarely does; with
    # no stub header left to say so, that is the best remaining evidence, and
    # it is only ever weighed for a record whose payload is already missing.
    def self.version_shaped?(remainder) = remainder.match?(/\A\d/)
    private_class_method :version_shaped?

    attr_reader :file

    def initialize(file)
      @file = file
    end
    private_class_method :new

    def to_s = file.to_s

    def delete
      File.delete(file)
    end
  end
end

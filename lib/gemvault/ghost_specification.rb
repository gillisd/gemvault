require "pathname"

module Gemvault
  ##
  # A gem specification file whose gem directory is gone -- the wreckage of an
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
  class GhostSpecification
    # All ghost specifications of +name+ across +roots+ (gem homes as listed
    # on Gem.path, the same view Bundler's plugin installer resolves against).
    def self.of(name, roots: Gem.path)
      roots.flat_map { |root| in_root(Pathname(root), name) }
    end

    def self.in_root(root, name)
      root.join("specifications").glob("#{name}-*.gemspec")
          .filter_map { |file| Gem::Specification.load(file.to_s) }
          .select { |spec| spec.name == name && !File.directory?(spec.full_gem_path) }
          .map { |spec| new(Pathname(spec.loaded_from)) }
    end
    private_class_method :in_root

    attr_reader :file

    def initialize(file)
      @file = file
    end

    def delete
      file.delete
    end
  end
end

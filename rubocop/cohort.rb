# frozen_string_literal: true

require 'pathname'
require 'rubocop'
require 'yaml'

##
# A group of targets that cops should be restricted to.
#
# ==== Glossary
#
# [target]  A file a cop acts on.  Targets are not polymorphic in this
#           system, so they are plain +Pathname+s relative to the repository
#           root rather than a class of their own.
# [cohort]  The group of targets included for cop targeting.  Which targets
#           belong is the subclass's decision; +Cohort+ itself is abstract.
# [cop key] The string RuboCop configuration keys cops by: a cop badge such
#           as <tt>Style/FrozenStringLiteralComment</tt> or a department such
#           as <tt>Acme/Spec</tt>.
# [plugin]  RuboCop's own term for a gem that contributes cops.
#
# ==== Invariants
#
# * A cohort scopes at least one cop key; construction fails otherwise.
# * Rendering never produces an empty +Include+ -- RuboCop treats that as
#   "every file", so an empty cohort renders a glob matching nothing instead.
# * Targets are +Pathname+s relative to the repository root, matching the
#   paths RuboCop resolves +Include+ globs against.
#
# Rendered into a +.rubocop.yml+ through its ERB preamble:
#
#   <% require 'branch_cohort' %>
#   plugins:
#     - rubocop-acme-spec
#   <%= BranchCohort.create plugins: ['rubocop-acme-spec'] %>
module RuboCop
  class Cohort
    ##
    # Glob that deliberately matches no file, rendered when the cohort is
    # empty so the configuration fails closed.
    NOTHING = ['**/.rubocop-matches-nothing'].freeze

    ##
    # Builds a cohort scoping every cop key in +cops+, plus every key each
    # named plugin introduces.  An optional block filters membership: each
    # target is yielded and kept only when the block returns a truthy value.
    #
    #   BranchCohort.create plugins: ['rubocop-rspec', 'rubocop-performance']
    #   BranchCohort.create(cops: ['Style/FrozenStringLiteralComment']) do |target|
    #     target.extname == '.rb'
    #   end
    def self.create(...)
      new(...)
    end

    def initialize(plugins: [], cops: [], &filter)
      @cops = Array(cops) + Array(plugins).flat_map { |name| Plugin.new(name).cops }
      @filter = filter
      raise ArgumentError, 'nothing to scope: pass plugins: and/or cops:' if @cops.empty?
    end

    ##
    # The cop keys this cohort restricts.
    attr_reader :cops

    ##
    # The member targets, after any filter block.
    def targets
      @targets ||= @filter ? members.select(&@filter) : members
    end

    ##
    # Renders the cohort as a RuboCop configuration fragment: one +Include+
    # per cop key.  This is what an ERB <tt><%= %></tt> interpolates.
    def to_s
      @cops.to_h { |cop| [cop, { 'Include' => globs }] }
           .to_yaml
           .delete_prefix("---\n")
    end

    private

    ##
    # The unfiltered targets.  Subclasses decide membership.
    def members
      raise NotImplementedError, "#{self.class}#members"
    end

    def globs
      targets.empty? ? NOTHING.dup : targets.map(&:to_s)
    end

    ##
    # A RuboCop plugin gem, resolved to the cop and department keys it
    # introduces: everything its +config/default.yml+ declares, minus the keys
    # RuboCop already ships.  The subtraction drops core cops the plugin merely
    # retunes -- rubocop-rspec, for instance, adjusts
    # <tt>Metrics/BlockLength</tt>, which is not its cop to restrict.
    class Plugin
      def initialize(name)
        @name = name
      end

      ##
      # Returns the plugin's own cop keys, including its department keys.
      def cops
        declared - core
      end

      private

      def declared
        keys_of("#{Gem::Specification.find_by_name(@name).gem_dir}/config/default.yml")
      end

      def core
        keys_of(RuboCop::ConfigLoader::DEFAULT_FILE)
      end

      def keys_of(path)
        YAML.load_file(path, permitted_classes: [Regexp, Symbol]).keys
      end
    end
  end
end

# frozen_string_literal: true

require 'open3'

require_relative 'cohort'

##
# A Cohort whose members are the files touched on the current branch:
# committed, staged, unstaged and untracked, relative to the base branch's
# merge point.  Deleted files are never members.
#
# Git commands run in the current working directory.  Inside a
# +.rubocop.yml+ ERB preamble that is always the directory holding the
# configuration file, because RuboCop changes directory before evaluating
# it; reusing the class elsewhere means providing that guarantee yourself.
#
# When membership cannot be established -- no repository, no recognisable
# base branch, or no merge point (typically a shallow clone) -- the cohort
# is empty, and says so once on standard error rather than silently
# widening or narrowing the lint.
module RuboCop
  class BranchCohort < Cohort
    ##
    # Refs tried in order when no <tt>base:</tt> is given.
    CANDIDATE_BASES = %w[origin/HEAD origin/main origin/master main master].freeze

    ##
    # Accepts the keywords and block of Cohort.create, plus <tt>base:</tt> to
    # name the ref the branch is compared against and <tt>git:</tt> to inject
    # a command runner.
    def initialize(base: nil, git: Git.new, **cohort_options, &filter)
      @git = git
      @base = base || detect_base
      super(**cohort_options, &filter)
    end

    private

    def members
      return none('no base branch found') if @base.nil?

      point = @git.lines('merge-base', @base, 'HEAD')&.first
      return none("no merge point with #{@base} (shallow clone?)") if point.nil?

      paths(point)
    end

    def paths(point)
      changed = @git.lines('diff', '--name-only', '--diff-filter=d', point) || []
      untracked = @git.lines('ls-files', '--others', '--exclude-standard') || []
      (changed + untracked).uniq.map { |path| Pathname.new(path) }
    end

    def detect_base
      CANDIDATE_BASES.find { |ref| @git.ref?(ref) }
    end

    def none(reason)
      warn "#{self.class}: #{reason}; cohort is empty"
      []
    end

    ##
    # Runs git with argument vectors -- never through a shell, so refs and
    # paths are data, not syntax.
    class Git
      ##
      # Returns the command's stdout as an array of lines, or +nil+ when the
      # command fails.  An empty array therefore means "succeeded, no output".
      def lines(*args)
        out, status = Open3.capture2('git', *args, err: File::NULL)
        status.success? ? out.split("\n") : nil
      end

      ##
      # Returns whether +ref+ resolves in the current repository.
      def ref?(ref)
        !lines('rev-parse', '--verify', '--quiet', ref).nil?
      end
    end
  end
end

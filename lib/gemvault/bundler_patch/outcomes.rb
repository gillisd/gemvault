module Gemvault
  class BundlerPatch
    # The aggregate of running Apply or Revert across every discovered
    # BundlerInstallation. Enumerable over Outcome variants; #summary
    # collapses to a single representative -- the Outcome class when all
    # agree, :mixed when divergent, :no_installations when empty.
    class Outcomes
      include Enumerable

      def initialize(outcomes)
        @outcomes = outcomes.freeze
      end

      def each(&)
        @outcomes.each(&)
      end

      def empty?
        @outcomes.empty?
      end

      def summary
        return :no_installations if empty?
        return :mixed if divergent?

        @outcomes.first.class
      end

      private

      def divergent?
        @outcomes.map(&:class).uniq.size > 1
      end
    end
  end
end

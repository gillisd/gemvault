module Gemvault
  module GemReference
    ##
    # Matches every version of a named gem stored in the vault.
    class AnyVersion < Data.define(:name)
      include GemReference

      def matches?(gem) = gem.name == name
    end
  end
end

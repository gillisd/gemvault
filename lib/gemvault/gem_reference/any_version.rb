module Gemvault
  module GemReference
    # Matches every version of a named gem stored in the vault.
    AnyVersion = Data.define(:name).freeze
  end
end

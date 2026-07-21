module Gemvault
  # One member of a vault's tar archive: a named blob of bytes. A value object
  # so archive code names what it moves around instead of juggling raw arrays.
  class ArchiveEntry < Data.define(:name, :bytes)
  end
end

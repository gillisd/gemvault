require "forwardable"

module Gemvault
  class CLI
    ##
    # A VaultDestination as the CLI presents it: the same operations, with the
    # directories they grow narrated on +stdout+ so nothing appears on disk
    # unannounced. What the destination refuses still surfaces as
    # <tt>VaultDestination::Error</tt> for the command to report.
    class Destination
      extend Forwardable

      def_delegators :@destination, :path, :refuse_existing

      def initialize(destination, stdout:)
        @destination = destination
        @stdout = stdout
      end

      # Creates the destination's missing parent directories, reporting the
      # shallowest one created so the user learns where the tree grew.
      def create_parents
        missing = @destination.missing_directory
        @destination.create_parents
        @stdout.puts "Created directory #{missing}" if missing
      end
    end
  end
end

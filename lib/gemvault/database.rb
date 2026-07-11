require "sequel"

module Gemvault
  # Connects to a vault's SQLite database with the driver appropriate for the
  # running engine: the sqlite3 C extension on MRI, the jdbc-sqlite3 JDBC
  # driver on JRuby. Both are presented as a single Sequel::Database.
  module Database
    module_function

    def connect(path)
      if RUBY_ENGINE == "jruby"
        require "jdbc/sqlite3"
        Sequel.connect("jdbc:sqlite:#{path}")
      else
        require "sqlite3"
        Sequel.connect(adapter: "sqlite", database: path)
      end
    end
  end
end

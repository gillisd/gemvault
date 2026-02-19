# frozen_string_literal: true

require_relative "vault"
require_relative "version"

module Gemvault
  module CLI
    COMMANDS = %w[new add list remove extract version help].freeze

    def self.run(argv)
      command = argv.shift

      case command
      when "new"     then cmd_new(argv)
      when "add"     then cmd_add(argv)
      when "list"    then cmd_list(argv)
      when "remove"  then cmd_remove(argv)
      when "extract" then cmd_extract(argv)
      when "version" then cmd_version
      when "help", nil then cmd_help
      else
        $stderr.puts "Unknown command: #{command}"
        $stderr.puts "Run 'gemvault help' for usage."
        1
      end
    end

    def self.cmd_new(argv)
      name = argv.shift
      unless name
        $stderr.puts "Usage: gemvault new NAME"
        return 1
      end

      path = name.end_with?(".gemv") ? name : "#{name}.gemv"

      if File.exist?(path)
        $stderr.puts "Error: #{path} already exists"
        return 1
      end

      vault = Vault.new(path, create: true)
      vault.close
      puts "Created #{path}"
      0
    end

    def self.cmd_add(argv)
      vault_path = argv.shift
      gem_paths = argv

      if !vault_path || gem_paths.empty?
        $stderr.puts "Usage: gemvault add VAULT GEM [GEM...]"
        return 1
      end

      vault = Vault.new(vault_path)
      begin
        gem_paths.each do |gem_path|
          vault.add(gem_path)
          spec = Gem::Package.new(gem_path).spec
          puts "Added #{spec.name}-#{spec.version}"
        end
      ensure
        vault.close
      end
      0
    rescue Vault::Error => e
      $stderr.puts "Error: #{e.message}"
      1
    end

    def self.cmd_list(argv)
      vault_path = argv.shift
      unless vault_path
        $stderr.puts "Usage: gemvault list VAULT"
        return 1
      end

      vault = Vault.new(vault_path)
      begin
        entries = vault.list
        if entries.empty?
          puts "Vault is empty"
        else
          entries.each do |entry|
            line = "#{entry['name']}-#{entry['version']}"
            line += " (#{entry['platform']})" if entry["platform"] != "ruby"
            puts line
          end
        end
      ensure
        vault.close
      end
      0
    rescue Vault::Error => e
      $stderr.puts "Error: #{e.message}"
      1
    end

    def self.cmd_remove(argv)
      vault_path = argv.shift
      name = argv.shift

      unless vault_path && name
        $stderr.puts "Usage: gemvault remove VAULT NAME [VERSION]"
        return 1
      end

      version = argv.shift

      vault = Vault.new(vault_path)
      begin
        count = vault.remove(name, version)
        if count == 0
          $stderr.puts "Error: No matching gem found"
          return 1
        end
        puts "Removed #{count} gem(s)"
      ensure
        vault.close
      end
      0
    rescue Vault::Error => e
      $stderr.puts "Error: #{e.message}"
      1
    end

    def self.cmd_extract(argv)
      output_dir = "."

      # Parse -o/--output flag
      i = 0
      while i < argv.length
        if argv[i] == "-o" || argv[i] == "--output"
          argv.delete_at(i)
          output_dir = argv.delete_at(i) || "."
        else
          i += 1
        end
      end

      vault_path = argv.shift
      name = argv.shift

      unless vault_path && name
        $stderr.puts "Usage: gemvault extract VAULT NAME [VERSION] [-o DIR]"
        return 1
      end

      version = argv.shift

      vault = Vault.new(vault_path)
      begin
        FileUtils.mkdir_p(output_dir)

        if version
          data = vault.gem_data(name, version)
          filename = "#{name}-#{version}.gem"
          File.binwrite(File.join(output_dir, filename), data)
          puts "Extracted #{filename}"
        else
          # Extract all versions
          entries = vault.gem_entries.select { |e| e["name"] == name }
          if entries.empty?
            $stderr.puts "Error: No gem named '#{name}' in vault"
            return 1
          end
          entries.each do |entry|
            data = vault.gem_data(entry["name"], entry["version"], platform: entry["platform"])
            full_name = "#{entry['name']}-#{entry['version']}"
            full_name += "-#{entry['platform']}" if entry["platform"] != "ruby"
            filename = "#{full_name}.gem"
            File.binwrite(File.join(output_dir, filename), data)
            puts "Extracted #{filename}"
          end
        end
      ensure
        vault.close
      end
      0
    rescue Vault::Error => e
      $stderr.puts "Error: #{e.message}"
      1
    end

    def self.cmd_version
      puts "gemvault #{VERSION}"
      0
    end

    def self.cmd_help
      puts <<~HELP
        Usage: gemvault COMMAND [OPTIONS]

        Commands:
          new NAME                        Create a new vault (NAME.gemv)
          add VAULT GEM [GEM...]          Add gem files to a vault
          list VAULT                      List gems in a vault
          remove VAULT NAME [VERSION]     Remove gem(s) from a vault
          extract VAULT NAME [VERSION]    Extract gem file(s) from a vault
          version                         Print version
          help                            Show this help

        Options:
          -o, --output DIR                Output directory for extract (default: .)

        Gemfile usage:
          # REQUIRED until bundler-source-vault is published to rubygems.org:
          plugin "bundler-source-vault", path: "/path/to/gemvault"

          source "myvault.gemv", type: :vault do
            gem "foo"
          end
      HELP
      0
    end
  end
end

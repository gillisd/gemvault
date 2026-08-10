require_relative "gem_index_files"

# Serves the tree's gems (built by TreeGems), plus their runtime dependencies,
# from a local RubyGems index, standing in for rubygems.org so Bundler's
# plugin installer can be exercised offline.
module GemIndex
  PORT = 8808

  # `bundle plugin install` resolves every declared dependency of the plugin
  # against the Gemfile's sources with GEM_PATH already narrowed to the plugin
  # root, so an ambient installed copy satisfies nothing -- the index has to
  # serve the dependency closure of the gems it offers. Every gem that
  # `gem install` put on the image left its .gem in the gem cache, exactly as
  # on a real machine, so dependencies are copied out of the cache rather than
  # fetched over the network.
  DEPS_RB = <<~RUBY.freeze
    require "rubygems/package"
    require "fileutils"
    require "pathname"

    gems_dir = Pathname(ARGV.first)
    served = gems_dir.glob("*.gem").map { |gem_file| Gem::Package.new(gem_file.to_s).spec }
    names = served.map(&:name)
    missing = served.flat_map(&:runtime_dependencies)
    until missing.empty?
      dependency = missing.shift
      next if names.include?(dependency.name)

      names.push(dependency.name)
      installed = Gem::Specification.find_by_name(dependency.name, *dependency.requirement.as_list)
      FileUtils.cp(installed.cache_file, gems_dir.to_s)
      missing.concat(installed.runtime_dependencies)
    end
  RUBY

  # The index files themselves -- both protocols -- are rendered by the script
  # in GemIndexFiles.
  MKINDEX_RB = GemIndexFiles::MKINDEX_RB

  HTTPD_RB = <<~'RUBY'.freeze
    require "socket"
    require "pathname"

    def read_request(client)
      request = client.gets or return
      nil while (line = client.gets) && line != "\r\n"
      request.split.first(2)
    end

    def respond(client, status, body: "", write_body: true)
      client.print "HTTP/1.1 #{status}\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n"
      client.print body if write_body
    end

    def serve(client, file, method)
      return respond(client, "404 Not Found") unless file.file?

      respond(client, "200 OK", body: file.binread, write_body: method != "HEAD")
    end

    root = Pathname(ARGV.first)
    server = TCPServer.new("127.0.0.1", Integer(ARGV.last))

    loop do
      Thread.new(server.accept) do |client|
        method, path = read_request(client)
        serve(client, root.join(path.sub(/\?.*/, "").delete_prefix("/")), method) if path
      rescue StandardError
        nil
      ensure
        client.close
      end
    end
  RUBY

  def self.serve_preamble
    <<~SH
      #{TreeGems.build_preamble}
      mkdir -p /work/index/gems
      cp /work/src/*.gem /work/src/shim/*.gem /work/index/gems/
      cat > /work/deps.rb <<'DEPS_RB'
      #{DEPS_RB}
      DEPS_RB
      cat > /work/mkindex.rb <<'MKINDEX_RB'
      #{MKINDEX_RB}
      MKINDEX_RB
      cat > /work/httpd.rb <<'HTTPD_RB'
      #{HTTPD_RB}
      HTTPD_RB
      ruby /work/deps.rb /work/index/gems
      ruby /work/mkindex.rb /work/index
      ruby /work/httpd.rb /work/index #{PORT} &
      for _ in $(seq 1 100); do
        ruby -rsocket -e 'TCPSocket.new("127.0.0.1", #{PORT}).close' 2>/dev/null && break
        sleep 0.1
      done
    SH
  end

  def self.gemrc_pointing_at_index
    "printf ':sources:\\n- http://127.0.0.1:#{PORT}/\\n' > /root/.gemrc\n"
  end

  def self.source_line
    %(source "http://127.0.0.1:#{PORT}")
  end

  # Bundler resolves a Gemfile-declared plugin against the Gemfile's own
  # sources, so a Gemfile with no rubygems source can only find the shim among
  # already-installed gems. Real Gemfiles name a rubygems source; these specs
  # name the local index so they resolve the tree's shim rather than a
  # published one.
  def self.with_source(gemfile_content)
    return gemfile_content if gemfile_content.include?(%(source "http))

    "#{source_line}\n\n#{gemfile_content}"
  end
end

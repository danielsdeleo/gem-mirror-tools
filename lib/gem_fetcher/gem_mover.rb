
module GemFetcher
  class GemMover

    RUBY = "ruby".freeze

    attr_reader :gem_base_name
    attr_reader :uri
    attr_reader :fetcher

    def initialize(gem_info_tuple)
      name, version, platform = gem_info_tuple
      @gem_base_name = "#{name}-#{version}#{"-#{platform}" unless platform == RUBY}.gem"
      @uri = "https://rubygems.org/gems/#{gem_base_name}"
      @fetcher = Fetcher.new
    end

    def write_gem_to(base_path)
      path = File.join(base_path, gem_base_name)
      puts "writing gem #{gem_base_name} to #{path}"
      write_file(gem_data, path)
    end

    def write_quick_marshal_to(base_path)
      basename = "#{indexable_spec.original_name}.gemspec.rz"
      path = File.join(base_path, basename)
      puts "writing quick marshal file for #{gem_base_name} to #{path}"
      write_file(zipped_marshaled_spec, path)
    end

    def zipped_marshaled_spec
      marshaled = Marshal.dump(indexable_spec)
      Zlib::Deflate.deflate(marshaled)
    end

    def indexable_spec
      @indexable_spec ||= sanitized_spec
    end

    def sanitized_spec
      spec = abbreviated_spec
      spec.summary              = sanitize_string(spec.summary)
      spec.description          = sanitize_string(spec.description)
      spec.post_install_message = sanitize_string(spec.post_install_message)
      spec.authors              = spec.authors.collect { |a| sanitize_string(a) }

      spec
    end

    def abbreviated_spec
      spec = full_spec
      spec.files = []
      spec.test_files = []
      spec.rdoc_options = []
      spec.extra_rdoc_files = []
      spec.cert_chain = []
      spec
    end

    def full_spec
      Gem::Format.from_io(StringIO.new(gem_data)).spec
    end

    def gem_data
      @gem_data ||= fetcher.fetch(uri)
    end

    def sanitize_string(string)
      string.to_s.fast_xs
    end

    def write_file(data, path)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'wb') do |output|
        output << data
      end
      true
    rescue Exception
      File.delete(path)
      raise
    end

    def puts(string)
      $stdout.print("#{string}\n")
    end

  end
end


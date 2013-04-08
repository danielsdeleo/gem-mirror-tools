
module GemFetcher

  class GemMover

    RUBY = "ruby".freeze

    attr_reader :gem_base_name
    attr_reader :uri
    attr_reader :fetcher
    attr_reader :gem_info_tuple
    attr_reader :name
    attr_reader :version
    attr_reader :platform

    def initialize(gem_info_tuple)
      @gem_info_tuple = gem_info_tuple
      @name, @version, @platform = gem_info_tuple
      @gem_base_name = "#{name}-#{version}#{"-#{platform}" unless platform == RUBY}.gem"
      @uri = "https://rubygems.org/gems/#{gem_base_name}"
      @fetcher = Fetcher.new
      @config = config
    end

    def config
      GemFetcher.config
    end

    ## FILE SHUFFLING

    def stage_gem
      path = staging_gem_path
      log "writing gem #{gem_base_name} to #{path}"
      write_file(gem_data, path)
    end

    def stage_quick_marshal
      path = staging_quick_marshal_path
      log "writing quick marshal file for #{gem_base_name} to #{path}"
      write_file(zipped_marshaled_spec, path)
    end

    def import_gem
      log "moving #{gem_base_name} from staging to #{prod_gem_path}"
      FileUtils.mkdir_p(File.dirname(prod_gem_path))
      FileUtils.mv(staging_gem_path, prod_gem_path)
    end

    def import_quick_marshal
      log "moving quick marshal file for #{gem_base_name} from staging to #{prod_quick_marshal_path}"
      FileUtils.mkdir_p(File.dirname(prod_quick_marshal_path))
      FileUtils.mv(staging_quick_marshal_path, prod_quick_marshal_path)
    end

    def staging_gem_path
      File.join(staging_gem_dir, gem_base_name)
    end

    def staging_quick_marshal_path
      basename = "#{indexable_spec.original_name}.gemspec.rz"
      File.join(staging_quick_marshal_dir, basename)
    end

    def intermediate_path
      basename_sans_ext = File.basename(gem_base_name, ".gem")
      intermediate_dir1 = basename_sans_ext[0...2]
      intermediate_dir2 = basename_sans_ext[0...4]
      File.join(intermediate_dir1, intermediate_dir2)
    end

    def prod_gem_path
      File.join(prod_gem_dir, intermediate_path, gem_base_name)
    end

    def prod_quick_marshal_path
      File.join(prod_gem_dir, intermediate_path, "#{indexable_spec.original_name}.gemspec.rz")
    end

    def staging_gem_dir
      @gem_dir ||= File.join(config.staging_dir, "gems")
    end

    def staging_quick_marshal_dir
      @quick_marshal_dir ||= File.join(config.staging_dir, "quick/Marshal.4.8")
    end

    def prod_gem_dir
      @prod_gem_dir ||= File.join(config.production_dir, "gems")
    end

    def prod_quick_marshal_dir
      @prod_quick_marshal_dir ||= File.join(config.production_dir, "quick/Marshal.4.8")
    end

    ## INDEX EXTRACTOR

    def prerelease?
      indexable_spec.version.prerelease?
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

    def log(string)
      $stdout.print("#{string}\n")
    end

  end
end


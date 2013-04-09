
module GemFetcher

  # Imports a "chunk" of gems from a staging location to the
  # "production" gem repo dir.
  class ChunkImporter

    attr_reader :gems
    attr_reader :pool

    def initialize(gems)
      @gems = gems
      @pool = Pool.new(10)

      @latest_specs_by_gem = nil
      @new_gems = nil
    end

    def config
      GemFetcher.config
    end

    def base_dir
      config.production_dir
    end

    def gem_dir
      @gem_dir ||= File.join(base_dir, "gems")
    end

    def quick_marshal_dir
      @quick_marshal_dir ||= File.join(base_dir, "quick/Marshal.4.8")
    end

    def new_gems
      if @new_gems.nil?
        @new_gems = []
        gems.each do |gem|
          if released_specs_index.include?(gem.gem_info_tuple)
            log "skipping gem #{gem.name} #{gem.version} (#{gem.platform})"
          else
            @new_gems << gem
          end
        end
        @new_gems.reverse!
      end
      @new_gems
    end

    def import
      if new_gems.empty?
        log "no new gems in chunk"
        return
      end

      stage_gems
      import_staged_gems
      update_spec_indexes

      # require 'pp'
      # pp :released => released_specs_index
      # pp :prerelease => prerelease_specs_index
      # pp :latest => latest_specs_index
      log "Imported #{new_gems.size} gems"
      log "Release gems: #{released_specs_index.size}"
      log "Prerelease:   #{prerelease_specs_index.size}"
      log "Latest gems:  #{latest_specs_index.size}"
    end

    def stage_gems
      gems.each do |gem|
        pool.job do
          gem.stage_gem
          gem.stage_quick_marshal
        end
      end
      pool.run_til_done
    end

    def import_staged_gems
      new_gems.each do |gem|
        gem.import_gem
        gem.import_quick_marshal
        add_to_specs_index(gem)
      end
    end

    def update_spec_indexes
      write_spec_index_update("specs.4.8", released_specs_index)
      write_spec_index_update("prerelease_specs.4.8", prerelease_specs_index)
      write_spec_index_update("latest_specs.4.8", latest_specs_index)
      mv_spec_index_update("specs.4.8")
      mv_spec_index_update("prerelease_specs.4.8")
      mv_spec_index_update("latest_specs.4.8")
    end

    def add_to_specs_index(gem)
      if gem.prerelease?
        prerelease_specs_index << gem.gem_info_tuple
      else
        released_specs_index << gem.gem_info_tuple
      end
      if current_latest_version = latest_specs_by_gem[gem.name]
        case gem.indexable_spec.version <=> current_latest_version[:version]
        when -1 # gem's version is less than current_latest_version[:version]
          # skip it
        when 0 # gem's version == current_latest_version[:version]
          # multiple gems w/ same name and version means the platforms
          # are different, so tack this one on to the list
          current_latest_version[:info_tuples] << gem.gem_info_tuple
        when 1 # gems' version is newer thant in current_latest_version
          latest_specs_by_gem[gem.name] = {:version => gem.version, :info_tuples => [gem.gem_info_tuple]}
        end
        # check if newer, replace
      else
        latest_specs_by_gem[gem.name] = {:version => gem.version, :info_tuples => [gem.gem_info_tuple]}
      end
    end

    def path_to_gem(file_name)
      intermediate_dir1 = file_name[0...2]
      intermediate_dir2 = file_name[0...4]
      File.join(gem_base_dir, intermediate_dir1, intermediate_dir2, file_name)
    end

    def all_gems
      @all_gems ||= Set.new(Dir["#{base_dir}/*/*/*gem"].map {|g| File.basename(g) })
    end

    def released_specs_index
      @released_specs_index ||= read_spec_index("specs.4.8")
    end

    def latest_specs_index
      latest_specs_by_gem.values.inject([]) {|index, i| index.concat(i[:info_tuples])}
    end

    def prerelease_specs_index
      @prerelease_specs_index ||= read_spec_index("prerelease_specs.4.8")
    end

    def latest_specs_by_gem
      if @latest_specs_by_gem.nil?
        @latest_specs_by_gem = {}
        spec_index = read_spec_index("latest_specs.4.8")
        spec_index.each do |name, version, platform|
          @latest_specs_by_gem[name] ||= {:version => version, :info_tuples => []}
          @latest_specs_by_gem[name][:info_tuples] << [name, version, platform]
        end
      end
      @latest_specs_by_gem
    end

    def write_spec_index_update(basename, data)
      path = File.join(base_dir, "#{basename}.gz.tmp")
      log "staging spec index '#{basename}' to #{path}"
      gzip(path, Marshal.dump(data))
    end

    def mv_spec_index_update(basename)
      tmp_path = File.join(base_dir, "#{basename}.gz.tmp")
      path = File.join(base_dir, "#{basename}.gz")
      log "installing spec index #{basename} at #{tmp_path} to #{path}"
      FileUtils.mv(tmp_path, path)
    end

    def read_spec_index(basename)
      path = File.join(base_dir, "#{basename}.gz")
      if File.exist?(path)
        log "loading spec index #{basename} from #{path}"
        Marshal.load(gunzip(path))
      else
        []
      end
    end

    def gunzip(file)
      File.open(file, "r") do |data|
        Zlib::GzipReader.new(data).read
      end
    end

    def gzip(filename, data)
      Zlib::GzipWriter.open("#{filename}") do |io|
        io.write(data)
      end
    end

    def log(string)
      $stdout.print("#{string}\n")
    end

    # def update_specs_index(index, source, dest)
    #   specs_index = Marshal.load Gem.read_binary(source)

    #   index.each do |spec|
    #     platform = spec.original_platform
    #     platform = Gem::Platform::RUBY if platform.nil? or platform.empty?
    #     specs_index << [spec.name, spec.version, platform]
    #   end

    #   specs_index = compact_specs specs_index.uniq.sort

    #   open dest, 'wb' do |io|
    #     Marshal.dump specs_index, io
    #   end
    # end
    
  end
end


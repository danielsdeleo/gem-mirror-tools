require 'zlib'
require 'set'

module GemFetcher
  class SpecIndexes

    def initialize
      @released_specs_index = nil
      @prerelease_specs_index = nil
    end

    def config
      GemFetcher.config
    end

    def base_dir
      config.production_dir
    end

    def include?(gem)
      released_specs_set.include?(gem.gem_info_tuple)
    end

    def commit_changes
      write_spec_index_update("specs.4.8", released_specs_index)
      write_spec_index_update("prerelease_specs.4.8", prerelease_specs_index)
      write_spec_index_update("latest_specs.4.8", latest_specs_index)
      mv_spec_index_update("specs.4.8")
      mv_spec_index_update("prerelease_specs.4.8")
      mv_spec_index_update("latest_specs.4.8")
    end

    def add_gem(gem)
      if gem.prerelease?
        prerelease_specs_index << gem.gem_info_tuple
      else
        released_specs_set << gem.gem_info_tuple
      end
      if current_latest_version = latest_specs_by_gem[gem.name]
        case gem.version <=> current_latest_version[:version]
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

    def released_specs_index
      released_specs_set.to_a
    end

    def released_specs_set
      if @released_specs_set.nil?
        specs_index = read_spec_index("specs.4.8")
        @released_specs_set = Set.new(specs_index)
      end
      @released_specs_set
    end


    def latest_specs_index
      latest_specs_by_gem.values.inject([]) {|index, i| index.concat(i[:info_tuples])}
    end

    def prerelease_specs_index
      @prerelease_specs_index ||= read_spec_index("prerelease_specs.4.8")
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

  end
end

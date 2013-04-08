
module GemFetcher

  # Imports a "chunk" of gems from a staging location to the
  # "production" gem repo dir.
  class ChunkImporter

    attr_reader :gems
    attr_reader :pool

    def initialize(gems)
      @gems = gems
      @pool = Pool.new(10)
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

    def stage
      gems.each do |gem|
        pool.job do
          gem.stage_gem
          gem.stage_quick_marshal
        end
      end
      pool.run_til_done
    end

    def import
      gems.each do |gem|
        gem.import_gem
        gem.import_quick_marshal
        add_to_specs_index(gem)
      end
      # require 'pp'
      # pp :released => released_specs_index
      # pp :prerelease => prerelease_specs_index
      # pp :latest => latest_specs_index
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
          latest_specs_by_gem[gem.name] = {:version => Gem::Version.new(gem.version), :info_tuples => [gem.gem_info_tuple]}
        end
        # check if newer, replace
      else
        latest_specs_by_gem[gem.name] = {:version => Gem::Version.new(gem.version), :info_tuples => [gem.gem_info_tuple]}
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

    # TODO: initially read from disk
    def released_specs_index
      @released_specs_index ||= []
    end

    def latest_specs_index
      latest_specs_by_gem.values.inject([]) {|index, i| index.concat(i[:info_tuples])}
    end

    # TODO: initially read from disk
    def prerelease_specs_index
      @prerelease_specs_index ||= []
    end

    # TODO: read from disk initially
    def latest_specs_by_gem
      @latest_specs_by_gem ||= {}
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


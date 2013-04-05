
module GemFetcher
  class ProductionRepo

    attr_reader :base_dir

    def initialize(base_dir)
      @base_dir = base_dir
    end

    def gem_dir
      @gem_dir ||= File.join(base_dir, "gems")
    end

    def quick_marshal_dir
      @quick_marshal_dir ||= File.join(base_dir, "quick/Marshal.4.8")
    end

    def import()
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
      raise "TODO"
    end

    def latest_specs_index
      raise "TODO"
    end

    def prerelease_specs_index
      raise "TODO"
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


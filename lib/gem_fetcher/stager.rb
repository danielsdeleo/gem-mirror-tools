
module GemFetcher
  class Stager
    attr_reader :base_dir
    attr_reader :gems_to_stage
    attr_reader :pool

    def initialize(base_dir, gems_to_stage)
      @base_dir = base_dir
      @gems_to_stage = gems_to_stage
      @pool = Pool.new(10)
    end

    def stage_gems
      gems_to_stage.each do |gem_mover|
        pool.job do
          stage(gem_mover)
        end
      end
      pool.run_til_done
    end

    def stage(gem_mover)
      gem_mover.write_gem_to(gem_dir)
      gem_mover.write_quick_marshal_to(quick_marshal_dir)
    end

    def gem_dir
      @gem_dir ||= File.join(base_dir, "gems")
    end

    def quick_marshal_dir
      @quick_marshal_dir ||= File.join(base_dir, "quick/Marshal.4.8")
    end

  end
end


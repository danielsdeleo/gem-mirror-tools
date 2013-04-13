require 'zlib'
require 'sinatra'
require 'sinatra/xsendfile'
require 'sinatra/config_file'
require 'singleton'
require 'thread'

configure do
  set :gem_dir, File.expand_path(Dir.pwd)
end

config_file "config.yml"

disable :protection

RUBY = "ruby".freeze

module Logging

  def log(msg)
    $stdout.print("#{msg}\n")
  end

end

module IndexedPaths
  def subdir_path_to(indexed_file)
    index1, index2 = indexed_file[0,2], indexed_file[0,4]
    File.join(index1, index2, indexed_file)
  end

  def expand_path(*components)
    full_path = File.expand_path(File.join(settings.gem_dir, *components))
    if full_path.include?(settings.gem_dir)
      full_path
    else
      nil
    end
  end
end

class IndexCache

  include Singleton
  include IndexedPaths
  include Logging

  class << self
    attr_accessor :settings
  end

  def settings
    self.class.settings
  end

  def initialize
    @spec_index_update_mutex = Mutex.new
    @released_specs_map = nil
    @spec_index_mtime = nil
    reset!
  end

  def reset!
    @spec_index_update_mutex.synchronize do
      @spec_index_mtime = current_spec_index_mtime
      released_specs_map = {}
      read_spec_index.each do |name, version, platform|
        released_specs_map[name] ||= []
        gem_filename = "#{name}-#{version}#{"-#{platform}" unless platform == RUBY}.gemspec.rz"
        released_specs_map[name] << gem_filename
      end
      @released_specs_map = released_specs_map
    end
  end

  def released_specs_by_gem
    unless current_spec_index_mtime == @spec_index_mtime
      reset!
    end
    @released_specs_map
  end

  def current_spec_index_mtime
    File.stat(spec_index_path).mtime
  end

  def spec_index_path
    File.join(settings.gem_dir, "specs.4.8.gz")
  end

  def read_spec_index
    log "loading spec index from #{spec_index_path}"
    Marshal.load(gunzip(spec_index_path))
  end

  def gunzip(file)
    File.open(file, "r") do |data|
      Zlib::GzipReader.new(data).read
    end
  end

  def read_quick_spec(gemspec_basename)
    gemspec_file_path = expand_path("quick/Marshal.4.8", subdir_path_to(gemspec_basename))
    marshal_data = Zlib::Inflate.inflate(IO.read(gemspec_file_path))
    Marshal.load(marshal_data)
  end

  def deps_info_for(gemspec_filename)
    gem = read_quick_spec(gemspec_filename)
    {
      :name => gem.name,
      :number => gem.version.to_s,
      :platform => gem.platform,
      :dependencies => gem.runtime_dependencies.map {|d| [d.name, d.requirement.to_s] }
    }
  end

  def dependencies_of(gem)
    # rubygems.org returns empty list for non-existent gems
    gem_filenames = released_specs_by_gem[gem] || []
    gem_filenames.map do |gemspec_filename|
      deps_info_for(gemspec_filename)
    end
  end
end
IndexCache.settings = settings
IndexCache.instance

include IndexedPaths
include Logging

%w[/specs.4.8.gz
   /latest_specs.4.8.gz
   /prerelease_specs.4.8.gz
].each do |index|
  get index do
    content_type('application/x-gzip')
    full_path = expand_path(index)
    log "Sending #{full_path}"
    send_file(full_path, :type => response['Content-Type'])
  end
end

get "/quick/Marshal.4.8/:quick_spec"  do |quick_spec|
  content_type('application/x-deflate')
  indexed_path = subdir_path_to(quick_spec)
  full_path = expand_path("quick/Marshal.4.8", indexed_path)
  log "Sending #{full_path}"
  send_file(full_path, :type => response['content-type'])
end

get "/gems/:gemname" do |gem|
  content_type('application/x-deflate')
  indexed_path = subdir_path_to(gem)
  full_path = expand_path("gems", indexed_path)
  log "Sending #{full_path}"
  send_file(full_path, :type => response['content-type'])
end

get '/api/v1/dependencies' do
  query_gems = params[:gems].to_s.split(',')
  deps = query_gems.inject([]) do |memo, query_gem|
    memo.concat(IndexCache.instance.dependencies_of(query_gem))
  end
  Marshal.dump(deps)
end

get '/' do
  IndexCache.instance.released_specs_by_gem.keys.sort.inject("") do |msg, gem_name|
    msg << "#{gem_name}\n"
  end
end



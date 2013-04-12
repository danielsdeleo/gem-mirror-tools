require 'zlib'
require 'sinatra'
require 'sinatra/xsendfile'
require 'sinatra/config_file'

configure do
  set :gem_dir, File.expand_path(Dir.pwd)
end

config_file "config.yml"

disable :protection

RUBY = "ruby".freeze

def subdir_path_to(indexed_file)
  indexable_part = indexed_file.split('-')[0..-2].join('-')
  index1, index2 = indexable_part[0,2], indexable_part[0,4]
  File.join(index1, index2, indexed_file)
end

def expand_path(*components)
  full_path = File.expand_path(File.join(settings.gem_dir, *components))
  unless full_path.include?(settings.gem_dir)
    halt 400, "nope #{request.path_info}"
  end
  full_path
end

def released_specs_by_gem
  released_specs_map = {}
  read_spec_index("specs.4.8.gz").each do |name, version, platform|
    released_specs_map[name] ||= []
    gem_filename = "#{name}-#{version}#{"-#{platform}" unless platform == RUBY}.gemspec.rz"
    released_specs_map[name] << gem_filename
  end
  released_specs_map
end

def read_spec_index(basename)
  path = File.join(settings.gem_dir, "#{basename}.gz")
  if File.exist?(path)
    log "loading spec index #{basename} from #{path}"
    Marshal.load(gunzip(path))
  else
    []
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
    :number => gem.number.version,
    :platform => gem.platform,
    :dependencies => runtime_dependencies(spec)
  }
end

def dependencies_of(gem)
  # rubygems.org returns empty list for non-existent gems
  gem_filenames = released_specs_by_gem[gem] || []
  gem_filenames.map do |gemspec_filename|
    deps_info_for(gemspec_filename)
  end
end

def log(msg)
  $stdout.print("#{msg}\n")
end

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
  full_path = expand_path("quick/marshal.4.8", indexed_path)
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
  deps = query_gems.inject([]){|memo, query_gem| memo.concat(dependencies_of(query_gem)) }
  Marshal.dump(deps)
end



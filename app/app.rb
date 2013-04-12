require 'sinatra'
require 'sinatra/xsendfile'
require 'sinatra/config_file'

config_file "config.yml"

configure do
  set :gem_dir, File.expand_path(Dir.pwd)
end

disable :protection

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

%w[/specs.4.8.gz
   /latest_specs.4.8.gz
   /prerelease_specs.4.8.gz
].each do |index|
  get index do
    content_type('application/x-gzip')
    full_path = expand_path(index)
    send_file(full_path, :type => response['Content-Type'])
  end
end

get "/quick/Marshal.4.8/:quick_spec"  do |quick_spec|
  content_type('application/x-deflate')
  indexed_path = subdir_path_to(quick_spec)
  full_path = expand_path("quick/marshal.4.8", indexed_path)
  send_file(full_path, :type => response['content-type'])
end

get "/gems/:gemname" do |gem|
  content_type('application/x-deflate')
  indexed_path = subdir_path_to(gem)
  full_path = expand_path("gems", indexed_path)
  send_file(full_path, :type => response['content-type'])
end


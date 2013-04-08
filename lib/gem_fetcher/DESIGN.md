# Integrated Mirror Tooling Design

Existing tools for mirroring rubygems have a bunch of inefficiencies.
By designing an integrated replacement suite, the process of setting up
a gem mirror can be made more resilient and efficient.

## Existing Process
Gems are downloaded directly to their final location by the `gem mirror`
command. It stores all files in a single directory, which causes
problems with NFS.

Once all gems are downloaded, you need to generate an index of the gems
before they can be served. The code that ships with rubygems to do this
chokes on a bunch of gems that are on rubygems.org, and is also slow.

### Index Build Steps:

* make_temp_directories
* build_indicies
  * Get gemspecs for all gems
  * build_marshal_gemspecs
  * build_modern_indicies if @build_modern
  * compress_indicies
* install_indicies

#### Resulting Dir Structure and File Locations

Gems:
MIRROR_ROOT/gems/$gem_name.gem

Specs:
MIRROR_ROOT/latest_specs.4.8
MIRROR_ROOT/latest_specs.4.8.gz
MIRROR_ROOT/prerelease_specs.4.8
MIRROR_ROOT/prerelease_specs.4.8.gz
MIRROR_ROOT/specs.4.8
MIRROR_ROOT/specs.4.8.gz

"Quick Marshal Files":
MIRROR_ROOT/quick/Marshal.4.8/


#### Load All Gemspecs

This caused a stack overflow for me when run without modification:

```ruby
  ######################################################################
  # TOP LEVEL
    Gem::Specification.add_specs(*map_gems_to_specs(gem_file_list))

  ######################################################################
  # gem_file_list
    Dir[File.join(@dest_directory, "gems", '*.gem')]

  ######################################################################
  # map_gems_to_specs
    gems.map { |gemfile|
      if File.size(gemfile) == 0 then
        alert_warning "Skipping zero-length gem: #{gemfile}"
        next
      end

      begin
        spec = Gem::Format.from_file_by_path(gemfile).spec
        spec.loaded_from = gemfile

        abbreviate spec
        sanitize spec

        spec
      rescue SignalException => e
        alert_error "Received signal, exiting"
        raise
      rescue Exception => e
        msg = ["Unable to process #{gemfile}",
               "#{e.message} (#{e.class})",
               "\t#{e.backtrace.join "\n\t"}"].join("\n")
        alert_error msg
      end
    }.compact

  ######################################################################
  # abbreviate spec
    spec.files = []
    spec.test_files = []
    spec.rdoc_options = []
    spec.extra_rdoc_files = []
    spec.cert_chain = []
    spec

  ######################################################################
  # Sanitize spec:
    spec.summary              = sanitize_string(spec.summary)
    spec.description          = sanitize_string(spec.description)
    spec.post_install_message = sanitize_string(spec.post_install_message)
    spec.authors              = spec.authors.collect { |a| sanitize_string(a) }

    spec

  ######################################################################
  # sanitize_string(string)
    return string unless string

    # HACK the #to_s is in here because RSpec has an Array of Arrays of
    # Strings for authors.  Need a way to disallow bad values on gemspec
    # generation.  (Probably won't happen.)
    string = string.to_s

    begin
      Builder::XChar.encode string
    rescue NameError, NoMethodError
      string.to_xs
    end

```


#### Build Marshal Gemspecs

```ruby
    Gem::Specification.each do |spec|
      spec_file_name = "#{spec.original_name}.gemspec.rz"
      marshal_name = File.join @quick_marshal_dir, spec_file_name

      marshal_zipped = Gem.deflate Marshal.dump(spec)
      open marshal_name, 'wb' do |io| io.write marshal_zipped end

      files << marshal_name

    end
    @files << @quick_marshal_dir
```

#### Build Modern Indices

```ruby
    prerelease, released = Gem::Specification.partition { |s|
      s.version.prerelease?
    }
    latest_specs = Gem::Specification.latest_specs

    build_modern_index(released.sort, @specs_index, 'specs')
    build_modern_index(latest_specs.sort, @latest_specs_index, 'latest specs')
    build_modern_index(prerelease.sort, @prerelease_specs_index,
                       'prerelease specs')

    @files += [@specs_index,
               "#{@specs_index}.gz",
               @latest_specs_index,
               "#{@latest_specs_index}.gz",
               @prerelease_specs_index,
               "#{@prerelease_specs_index}.gz"]
```

#### Compress Indices

```ruby
        gzip @specs_index
        gzip @latest_specs_index
        gzip @prerelease_specs_index
```

#### Index Format

```ruby
  specs_index << [spec.name, spec.version, platform]
```

# Redesign Proposal

## Downloader:

gem mirror code is mostly okay, but we want to make these changes:

* It needs to handle network errors more gracefully
* It needs to store gems by name[0...2]/name[0...4]/name so we don't
have to deal with NFS hash collision issue.
* It needs to either fetch or generate the abbreviated sanitized spec
and quick marshal files
* It needs to store gems and other files in a staging location

## Indexer

The existing indexer code chokes on lots of existing gems and generally
cannot gracefully handle the number of gems that now exist. It should be
updated:

* Use the above file structure
* Find new gems in the staging location, then move them to the final
location.
* Handle bad gems gracefully. Leave a "tombstone" file somewhere so the
downloader knows not to download them.



Gem Mirror Tools
================

Tools for mirroring rubygems.org.

Design
------

There are existing tools for mirroring rubygems, but I found them
difficult to work with. The design goals for this mirroring tool:

* Limit the number of files in a single directory. I want to store gems
on NFS. There are a few hundred thousand gems.  Due to a bug in
Linux/NFS/filesystem, it's impossible to list all of the entries in a
directory with that many files, so the existing gem mirror script wasn't
able to fetch all of the gems.
* Always make progress. Downloading or loading the specs from all of the
gems takes a long time. You might ^C the script, or your machine might
crash or get rebooted when you're 90% done.
* Amortize index generation. When downloading gems, all the information
you need to generate the index files is right there. By generating index
files while downloading, there is no need to later go back and read all
of the gems to generate indexes. See also: "always make progress".


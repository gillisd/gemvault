# GEMVAULT TAR SPIKE

## Problem

Gemvault has been working thus far, but the sqlite3 dependency makes the gem less portable then it should be:

1. The whole idea and basis of gemvault is that it _is_ a portable gem server in a file, and you shouldn't need dependencies to use it.
2. sqlite3 is not supported by jruby

## Solution

    Since gemvault is just reading blobs from sqlite3, and doesn't really need any of its other stuff, I propose using a simpler storage model - a tarball. *.gem files, otherwise known as  Packages, already are stored in this format, and all of the necessary equipment for reading them is already in rubygems, so it's a natural fit. If we are really worried about integrity that sqlite3 provides, we can use flock or similar to do locking. It is not intended or recommended to manipulate the tar version of the gemv file without going through gemvault, so anything beyond that is not supported. We shall refer to the tar version of a gemv file as a Tarvault and the sqlite3 version as a Dbvault to ensure communication is clear.

One can read all the gemspecs from a Tarvault using this chained oneliner:

```ruby
gemspecs = Enumerator.new { |y| Gem::Package::TarReader.new(File.open("tarvault.gemv")) { |reader| reader.each_entry { y << Gem::Package.new(it) } } }.map(&:spec)


```

All of the dependencies are already provided.

## Things to think about

1. A Dbvault makes it trivial to store additional information about a given Package. I think we can meet any needs for metadata via a json manifest or metadata file to keep as the very first entry in a Tarvault. So structure would resemble something like:

```
$ tar -tf tarvault.gemv

manifest.json
myprivategem-0.1.0.gem
rails-8.0.0.gem

```

1. For files like this, e.g. files within a file, what is the usual way to maintain integrity? Are checksums used?
2. Encryption can be supported by encrypting a Package directly, and appending the raw bytes directly to the Tarvault. The manifest can indicate that they are encrypted. OpenSSL can be used all the way through (Encryption is not to be done on this spike, but whether it is possible is a key factor)

## Notes

1. gemvault is below 1.0.0 at the moment and therefore does not guarantee any backwards compatibility with sqlite3 version or anything for that matter. Keeping this compatitble with the Dbvault is not something you should keep in mind. Move forward. Users can use an old version of gemvault if we decide that Tarvault is _the way_

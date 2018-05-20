ruby-xz
=======

**ruby-xz** is a basic binding to the famous [liblzma library][1],
best known for the extreme compression-ratio it's native *XZ* format
achieves. ruby-xz gives you the possibility of creating and extracting
XZ archives on any platform where liblzma is installed. No compilation
is needed, because ruby-xz is written on top of Ruby's fiddle library
(part of the standard libary). ruby-xz does not have any dependencies
other than Ruby itself.

ruby-xz supports both "intuitive" (de)compression by providing methods to
directly operate on strings and files, but also allows you to operate
directly on IO streams (see the various methods of the XZ module). On top
of that, ruby-xz offers an advanced interface that allows you to treat
XZ-compressed data as IO streams, both for reading and for writing. See the
XZ::StreamReader and XZ::StreamWriter classes for more information on this.

**Note**: Version 1.0.0 breaks the API quite heavily. Refer to
HISTORY.rdoc for details.

Installation
------------

Install it the way you install all your gems.

```
$ gem install ruby-xz
```

Alternatively, you can clone the repository and build the most recent
code yourself:

```
$ git clone git://github.com/Quintus/ruby-xz.git
$ cd ruby-xz
$ rake gem
$ gem install pkg/ruby-xz-*.gem
```

Usage
-----

The documentation of the XZ module is well and you should be able to find
everything you need to use ruby-xz. As said, it's not big, but powerful:
You can create and extract whole archive files, compress or decompress
streams of data or just plain strings.

You can read the documentation on your local gemserver, or browse it [online][2].

### Require ###

You have to require the “xz.rb” file:

``` ruby
require "xz"
```

### Examples ###

``` ruby
# Compress a file
XZ.compress_file("myfile.txt", "myfile.txt.xz")
# Decompress it
XZ.decompress_file("myfile.txt.xz", "myfile.txt")

# Compress everything you get from a socket (note that there HAS to be a EOF
# sometime, otherwise this will run infinitely)
XZ.compress_stream(socket){|chunk| opened_file.write(chunk)}

# Compress a string
comp = XZ.compress("Mydata")
# Decompress it
data = XZ.decompress(comp)
```

Have a look at the XZ module's documentation for an in-depth description of
what is possible.

### Usage with the minitar gem ###

ruby-xz can be used together with the [minitar][3] library (formerly
“archive-tar-minitar”) to create XZ-compressed tarballs. This works by
employing the IO-like classes XZ::StreamReader and XZ::StreamWriter
analogous to how one would use Ruby's “zlib” library together with
“minitar”. Example:

``` ruby
require "xz"
require "minitar"

# Create an XZ-compressed tarball
XZ::StreamWriter.open("tarball.tar.xz") do |txz|
  Minitar.pack("path/to/directory", txz)
end

# Unpack it again
XZ::StreamReader.open("tarball.tar.xz") do |txz|
  Minitar.unpack(txz, "path/to/target/directory")
end
```

Links
-----

* Website: https://mg.guelker.eu/projects/ruby-xz/
* Online documentation: https://mg.guelker.eu/projects/ruby-xz/doc
* Code repository: https://git.guelker.eu/?p=ruby-xz.git;a=summary
* Issue tracker: https://github.com/Quintus/ruby-xz/issues

License
-------

MIT license; see LICENSE for the full license text.

[1]: http://tukaani.org/xz/
[2]: https://mg.guelker.eu/projects/ruby-xz/doc
[3]: https://github.com/halostatue/minitar

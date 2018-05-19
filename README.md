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

**Note**: Version 1.0.0 breaks the API of the XZ::StreamReader and
XZ::StreamWriter classes. If you used them, you will need to adapt
your code. The API now behaves like Ruby's own zlib library does.

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

### First step ###

You have to require ruby-xz. Note the file you have to require is named
"xz.rb", so do

``` ruby
require "xz"
```

to get it.

### Examples ###

``` ruby
# Compress a TAR archive
XZ.compress_file("myfile.tar", "myfile.tar.xz")
# Decompress it
XZ.decompress_file("myfile.tar.xz", "myfile.tar")

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

Links
-----

* Code repository: https://github.com/Quintus/ruby-xz
* Issue tracker: https://github.com/Quintus/ruby-xz/issues
* Online documentation: http://quintus.github.io/ruby-xz

License
-------

MIT license; see LICENSE for the full license text.

[1]: http://tukaani.org/xz/
[2]: http://quintus.github.io/ruby-xz

ruby-xz
=======

**ruby-xz** is a basic binding to the famous [liblzma library][1],
best known for the extreme compression-ratio it's native *XZ* format
achieves. ruby-xz gives you the possibility of creating and extracting
XZ archives on any platform where liblzma is installed. No compilation
is needed, because ruby-xz is written ontop of
[ffi][2].

ruby-xz supports both "intuitive" (de)compression by providing methods to
directly operate on strings and files, but also allows you to operate
directly on IO streams (see the various methods of the XZ module). On top
of that, ruby-xz offers an advanced interface that allows you to treat
XZ-compressed data as IO streams, both for reading and for writing. See the
XZ::StreamReader and XZ::StreamWriter classes for more information on this.

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

You can read the documentation on your local gemserver, or browse it [online][3].

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

(The MIT License)

Basic liblzma-bindings for Ruby.

Copyright © 2011-2015 Marvin Gülker et al.

See AUTHORS for the full list of contributors.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the ‘Software’),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the Software
is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED ‘AS IS’, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

[1]: http://tukaani.org/xz/
[2]: https://github.com/ffi/ffi
[3]: http://quintus.github.io/ruby-xz

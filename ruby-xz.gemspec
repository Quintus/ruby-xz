#Encoding: UTF-8
=begin (The MIT License)

Basic liblzma-bindings for Ruby.

Copyright © 2011 Marvin Gülker

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
=end

require 'lib/xz'

GEMSPEC = Gem::Specification.new do |spec|
  spec.name = "ruby-xz"
  spec.summary = "XZ compression via liblzma for Ruby."
  spec.description =<<DESCRIPTION
This is a basic binding for liblzma that allows you to
create and extract XZ-compressed archives. It can cope with big
files as well as small ones, but doesn't offer much
of the possibilities liblzma itself has.
DESCRIPTION
  spec.version = XZ::VERSION.dup #Without dup, RubyGems complains it can't modify it...?
  spec.author = "Marvin Gülker"
  spec.email = "sutniuq@gmx.net"
  spec.platform = Gem::Platform::RUBY
  spec.required_ruby_version = ">=1.8.7"
  spec.add_dependency("ffi")
  spec.add_development_dependency("hanna-nouveau")
  spec.files.concat(Dir["lib/**/*.rb"])
  spec.files.concat(Dir["**/*.rdoc"])
  spec.has_rdoc = true
  spec.extra_rdoc_files = %w[README.rdoc]
  spec.rdoc_options << "-t" << "ruby-xz RDocs" << "-m" << "README.rdoc"
end

# -*- mode: ruby; coding: utf-8 -*-
# (The MIT License)
#
# Basic liblzma-bindings for Ruby.
#
# Copyright © 2011,2012,2013 Marvin Gülker
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the ‘Software’),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the Software
# is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED ‘AS IS’, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative "lib/xz/version"

GEMSPEC = Gem::Specification.new do |spec|
  spec.name        = "ruby-xz"
  spec.summary     = "XZ compression via liblzma for Ruby, using ffi."
  spec.description =<<DESCRIPTION
These are simple Ruby bindings for the liblzma library
(http://tukaani.org/xz/), which is best known for the
extreme compression ratio its native XZ format achieves.
Since FFI is used to implement the bindings, no compilation
is needed and they should work with JRuby as well.
DESCRIPTION
  spec.version               = XZ::VERSION.gsub("-", ".")
  spec.author                = "Marvin Gülker"
  spec.email                 = "quintus@quintilianus.eu"
  spec.license               = "MIT"
  spec.homepage              = "http://quintus.github.io/ruby-xz"
  spec.platform              = Gem::Platform::RUBY
  spec.required_ruby_version = ">=1.9.3"
  spec.add_runtime_dependency("ffi", "~> 1.9")
  spec.add_runtime_dependency("io-like", "~> 0.3")
  spec.add_development_dependency("archive-tar-minitar", "~> 0.5")
  spec.files.concat(Dir["lib/**/*.rb"])
  spec.files.concat(Dir["**/*.rdoc"])
  spec.files << "COPYING" << "AUTHORS"
  spec.has_rdoc         = true
  spec.extra_rdoc_files = %w[README.md HISTORY.rdoc COPYING AUTHORS]
  spec.rdoc_options << "-t" << "ruby-xz RDocs" << "-m" << "README.md"
end

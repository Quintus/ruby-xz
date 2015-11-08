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
  spec.summary     = "XZ compression via liblzma for Ruby."
  spec.description =<<DESCRIPTION
This is a basic binding for liblzma that allows you to
create and extract XZ-compressed archives. It can cope with big
files as well as small ones, but doesn't offer much
of the possibilities liblzma itself has.
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
  spec.files.concat(Dir["lib/**/*.rb"])
  spec.files.concat(Dir["**/*.rdoc"])
  spec.files << "COPYING" << "AUTHORS"
  spec.has_rdoc         = true
  spec.extra_rdoc_files = %w[README.md HISTORY.rdoc COPYING AUTHORS]
  spec.rdoc_options << "-t" << "ruby-xz RDocs" << "-m" << "README.md"
end

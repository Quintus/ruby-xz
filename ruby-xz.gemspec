# -*- mode: ruby; coding: utf-8 -*-
#--
# Basic liblzma-bindings for Ruby.
#
# Copyright © 2011-2018 Marvin Gülker et al.
#
# See AUTHORS for the full list of contributors.
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
#++

require_relative "lib/xz/version"

GEMSPEC = Gem::Specification.new do |spec|
  spec.name        = "ruby-xz"
  spec.summary     = "XZ compression via liblzma for Ruby, using fiddle."
  spec.description =<<DESCRIPTION
These are simple Ruby bindings for the liblzma library
(http://tukaani.org/xz/), which is best known for the
extreme compression ratio its native XZ format achieves.
Since fiddle is used to implement the bindings, no compilation
is needed.
DESCRIPTION
  spec.version               = XZ::VERSION.gsub("-", ".")
  spec.author                = "Marvin Gülker"
  spec.email                 = "m-guelker@phoenixmail.de"
  spec.license               = "MIT"
  spec.homepage              = "http://quintus.github.io/ruby-xz"
  spec.platform              = Gem::Platform::RUBY
  spec.required_ruby_version = ">=2.3.0"
  spec.add_development_dependency("minitar", "~> 0.6")
  spec.files.concat(Dir["lib/**/*.rb"])
  spec.files.concat(Dir["**/*.rdoc"])
  spec.files << "COPYING" << "AUTHORS"
  spec.has_rdoc         = true
  spec.extra_rdoc_files = %w[README.md HISTORY.rdoc LICENSE AUTHORS]
  spec.rdoc_options << "-t" << "ruby-xz RDocs" << "-m" << "README.md"
end

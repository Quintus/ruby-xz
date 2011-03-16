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

require "rake/gempackagetask"
gem "rdoc"
require "rdoc/task"

load "ruby-xz.gemspec"

Rake::GemPackageTask.new(GEMSPEC).define

Rake::RDocTask.new do |rd|
  rd.rdoc_files.include("lib/**/*.rb", "**/*.rdoc")
  rd.title = "ruby-xz RDocs"
  rd.main = "README.rdoc"
  rd.generator = "hanna" #Ignored if hanna-nouveau isn't installed
  rd.rdoc_dir = "doc"
end
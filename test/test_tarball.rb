# -*- coding: utf-8 -*-
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

require "minitar"
require_relative "common"

# Create XZ-compressed tarballs and unpack them with the system's
# tar(1) utility, and vice-versa. This ensures our library interacts
# with the environment as one expects it to.
class TarballTest < Minitest::Test

  def test_pack_tarball
    filename = File.join(Dir.pwd, "testtarball.tar.xz")
    content  = File.read("test-data/lorem_ipsum.txt")

    XZ::StreamWriter.open(filename) do |txz|
      Minitar.pack("test-data/lorem_ipsum.txt", txz)
    end

    Dir.mktmpdir("testtarball") do |dir|
      Dir.chdir(dir) do
        system("tar -xJf '#{filename}'")
        assert File.exist?("test-data/lorem_ipsum.txt"), "compressed file missing!"
        assert_equal File.read("test-data/lorem_ipsum.txt"), content
      end
    end
  ensure
    File.unlink(filename) if File.exist?(filename)
  end

  def test_unpack_tarball
    filename = File.join(Dir.pwd, "testtarball.tar.xz")
    content  = File.read("test-data/lorem_ipsum.txt")

    system("tar -cJf '#{filename}' test-data/lorem_ipsum.txt")

    Dir.mktmpdir("testtarball") do |dir|
      Dir.chdir(dir) do
        XZ::StreamReader.open(filename) do |txz|
          Minitar.unpack(txz, ".")
        end

        assert File.exist?("test-data/lorem_ipsum.txt"), "compresed file missing!"
        assert_equal File.read("test-data/lorem_ipsum.txt"), content
      end
    end
  ensure
    File.unlink(filename) if File.exist?(filename)
  end

end

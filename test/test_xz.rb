# -*- coding: utf-8 -*-
# (The MIT License)
# 
# Basic unit-tests for the liblzma-bindings for Ruby.
# 
# Copyright © 2011,2012 Marvin Gülker
# Copyright © 2011 Christoph Plank
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

if RUBY_VERSION >= "1.9"
  require_relative "./common"
else
  require File.join(File.expand_path(File.dirname(__FILE__)), 'common')
end

class TestXZ < Test::Unit::TestCase
  
  TEST_XZ = "\3757zXZ\000\000\004\346\326\264F\002\000!\001\026\000\000\000t/" +
  "\345\243\340\000\023\000\020]\000\030\fB\222jg\274\016\32132a\326|\000\000" +
  "\000\017:\376\373\"1\270\266\000\001,\024\370\nm\003\037\266\363}\001\000" +
  "\000\000\000\004YZ"
  
  def test_decompress
    assert_equal(XZ.decompress(TEST_XZ), '01234567890123456789')
  end

  def test_compress
    tmp = XZ.compress('01234567890123456789')
    assert_equal(tmp[0, 5].bytes.to_a, "\3757zXZ".bytes.to_a)
  end

  def test_compress_file
    Tempfile.open('in') do |infile|
      infile.write('01234567890123456789')
      infile.close

      Tempfile.open('out') do |outfile|
        outfile.close

        XZ.compress_file(infile.path, outfile.path)

        outfile.open
        assert_equal(outfile.read[0, 5].bytes.to_a, "\3757zXZ".bytes.to_a)
      end
    end
  end

  def test_decompress_file
    Tempfile.open('in') do |infile|
      infile.write(TEST_XZ)
      infile.close

      Tempfile.open('out') do |outfile|
        outfile.close

        XZ.decompress_file(infile.path, outfile.path)

        outfile.open
        assert_equal(outfile.read, '01234567890123456789')
      end
    end
  end
end


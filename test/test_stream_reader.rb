# -*- coding: utf-8 -*-
# (The MIT license)
#
# Basic liblzma-bindings for Ruby.
#
# Copyright © 2012,2013 Marvin Gülker
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

class StreamReaderTest < Test::Unit::TestCase

  TEST_DATA_DIR   = Pathname.new(__FILE__).dirname + "test-data"
  PLAIN_TEXT_FILE = TEST_DATA_DIR + "lorem_ipsum.txt"
  XZ_TEXT_FILE    = TEST_DATA_DIR + "lorem_ipsum.txt.xz"

  def test_new
    File.open(XZ_TEXT_FILE) do |file|
      reader = XZ::StreamReader.new(file)
      
      assert_equal("Lorem ipsum", reader.read(11))
      assert_equal(" dolor sit amet", reader.read(15))
      
      rest = reader.read
      assert_equal("Lorem ipsum dolor sit amet.\n", rest[-28..-1])
      assert_equal("", reader.read) # We’re at EOF
      assert(reader.eof?, "EOF is not EOF!")
      
      reader.close
    end
  end

  def test_file_closing
    File.open(XZ_TEXT_FILE, "rb") do |file|
      XZ::StreamReader.new(file){|r| r.read}
      assert(!file.closed?, "Closed file although not expected!")
    end

    File.open(XZ_TEXT_FILE, "rb") do |file|
      reader = XZ::StreamReader.new(file)
      reader.read
      reader.close
      assert(!file.closed?, "Closed file although not expected!")
    end

    reader = XZ::StreamReader.new(XZ_TEXT_FILE){|r| r.read}
    assert(reader.instance_variable_get(:@file).closed?, "Didn't close internally created file!")

    reader = XZ::StreamReader.new(XZ_TEXT_FILE)
    reader.read
    reader.close
    assert(reader.instance_variable_get(:@file).closed?, "Didn't close internally created file!")

    File.open(XZ_TEXT_FILE, "rb") do |file|
      XZ::StreamReader.new(file) do |r|
        r.read(10)
        r.rewind
        assert(!file.closed?, "Closed handed IO during rewind!")
      end
    end

    XZ::StreamReader.new(XZ_TEXT_FILE) do |r|
      r.read(10)
      r.rewind
      assert(!r.instance_variable_get(:@file).closed?, "Closed internal file during rewind")
    end

    # Test double closing
    assert_nothing_raised do
      XZ::StreamReader.open(XZ_TEXT_FILE) do |r|
        r.close
      end
    end
    
  end

  def test_open
    XZ::StreamReader.open(XZ_TEXT_FILE) do |reader|
      assert_equal(File.read(PLAIN_TEXT_FILE), reader.read)
    end
  end

  def test_pos
    text = File.read(PLAIN_TEXT_FILE)
    XZ::StreamReader.open(XZ_TEXT_FILE) do |reader|
      reader.read
      assert_equal(text.bytes.count, reader.pos)
    end
  end

  def test_rewind
    # Non-block form
    File.open(XZ_TEXT_FILE, "rb") do |file|
      reader = XZ::StreamReader.new(file)
      text = reader.read(10)
      reader.rewind
      assert_equal(text, reader.read(10))
    end

    # Block form
    XZ::StreamReader.open(XZ_TEXT_FILE) do |reader|
      text = reader.read(10)
      reader.rewind
      assert_equal(text, reader.read(10))
    end
  end

end

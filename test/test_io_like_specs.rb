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

require_relative "./common"

# This test checks whether or not we conform to the
# contracts enforced by the io-like gem.
#
# Note that this test checks a private API (the one exposed
# to the IO::Like library), hence the many calls to #send.
class IOLikeSpecsTest < Minitest::Test

  TEST_DATA_DIR   = Pathname.new(__FILE__).dirname + "test-data"
  PLAIN_TEXT_FILE = TEST_DATA_DIR + "lorem_ipsum.txt"
  XZ_TEXT_FILE    = TEST_DATA_DIR + "lorem_ipsum.txt.xz"
  LIVE_TEST_FILE  = TEST_DATA_DIR + "lorem2.txt.xz"

  def setup
    @rfile  = File.open(XZ_TEXT_FILE, "rb")
    @wfile  = File.open(LIVE_TEST_FILE, "wb")
    @reader = XZ::StreamReader.new(@rfile)
    @writer = XZ::StreamWriter.new(@wfile)
  end

  def teardown
    @reader.close
    @writer.close
    @rfile.close
    @wfile.close
    LIVE_TEST_FILE.delete
  end

  def test_reader_definition
    assert_equal(1, XZ::StreamReader.instance_method(:unbuffered_read).arity)
  end

  def test_reader_length
    str = @reader.send(:unbuffered_read, 100_000)
    assert(100_000 >= str.bytes.count)
  end

  def test_reader_eof
    @reader.send(:unbuffered_read, 100_000)
    assert_raises(EOFError){@reader.send(:unbuffered_read, 100_000)}
  end

  def test_writer_definition
    assert_equal(1, XZ::StreamWriter.instance_method(:unbuffered_write).arity)
  end

  def test_writer_writelen
    text = "Foo Baz Baz"
    assert(text.bytes.count >= @writer.send(:unbuffered_write, text))
  end

end

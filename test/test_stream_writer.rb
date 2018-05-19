# -*- coding: utf-8 -*-
# (The MIT license)
#
# Basic liblzma-bindings for Ruby.
#
# Copyright © 2012,2013,2015,2018 Marvin Gülker
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

# For this testcase, please note that it isn’t possible to check
# whether the compressed string is equal to some other
# compressed string containing the same original text due to
# different compression options and/or different versions of
# liblzma. Hence, I can only test whether the re-decompressed
# result is equal to what I originally had.
class StreamWriterTest < Minitest::Test

  TEST_DATA_DIR   = Pathname.new(__FILE__).dirname + "test-data"
  PLAIN_TEXT_FILE = TEST_DATA_DIR + "lorem_ipsum.txt"
  XZ_TEXT_FILE    = TEST_DATA_DIR + "lorem_ipsum.txt.xz"
  LIVE_TEST_FILE  = TEST_DATA_DIR + "lorem2.txt.xz"

  def test_stream_writer_new
    text   = File.read(PLAIN_TEXT_FILE)
    text1  = text[0...10]
    text2  = text[10..-1]

    File.open(LIVE_TEST_FILE, "wb") do |file|
      writer = XZ::StreamWriter.new(file)

      assert_equal(text1.bytes.count, writer.write(text1))
      assert_equal(text2.bytes.count, writer.write(text2))
      assert(text.bytes.count > writer.close)
      assert(writer.finished?, "Didn't finish writer")
      assert(writer.closed?, "Didn't close writer")
      assert_raises(IOError){writer.write("foo")}
    end

    assert_equal(text, XZ.decompress(File.open(LIVE_TEST_FILE, "rb"){|f| f.read}))
  end

  def test_file_closing
    File.open(LIVE_TEST_FILE, "wb") do |file|
      w = XZ::StreamWriter.new(file)
      w.write("Foo")
      w.finish
      assert(!file.closed?, "Closed file although not expected!")
    end

    File.open(LIVE_TEST_FILE, "wb") do |file|
      w = XZ::StreamWriter.new(file)
      w.write("Foo")
      w.close
      assert(file.finished?, "Didn't finish writer although expected!")
      assert(file.closed?, "Didn't close file although expected!")
    end

    writer = XZ::StreamWriter.open(LIVE_TEST_FILE){|w| w.write("Foo")}
    assert(writer.finished?, "Didn't finish writer")
    assert(writer.instance_variable_get(:@delegate_io).closed?, "Didn't close internally opened file!")

    writer = XZ::StreamWriter.new(LIVE_TEST_FILE)
    writer.write("Foo")
    writer.close
    assert(writer.finished?, "Didn't finish writer")
    assert(writer.instance_variable_get(:@delegate_io).closed?, "Didn't close internally opened file!")

    # Test double closing (this should not raise)
    XZ::StreamWriter.open(LIVE_TEST_FILE) do |w|
      w.write("Foo")
      w.close
    end
  end

  def test_finish
    File.open(LIVE_TEST_FILE, "wb") do |file|
      XZ::StreamWriter.open(file) do |w|
        w.write("Foo")
        assert_equal file, w.finish
      end

      assert !file.closed?, "Closed wrapped file despite of #finish!"
    end

    File.open(LIVE_TEST_FILE, "wb") do |file|
      w = XZ::StreamWriter.new(file)
      w.write("Foo")

      assert_equal file, w.finish
      assert !file.closed?, "Closed wrapped file despite of #finish!"
    end

    file = nil
    XZ::StreamWriter.open(LIVE_TEST_FILE){|w| w.write("Foo"); file = w.finish}
    assert_kind_of File, file # Return value of #finish
    assert !file.closed?, "Closed wrapped file despite of #finish!"
    file.close # cleanup

    writer = XZ::StreamWriter.open(LIVE_TEST_FILE)
    writer.write("Foo")
    file = writer.finish
    assert_kind_of File, file
    assert !file.closed?, "Closed wrapped file despite of #finish!"
    file.close # cleanup
  end

  def test_stream_writer_open
    text = File.read(PLAIN_TEXT_FILE)

    XZ::StreamWriter.open(LIVE_TEST_FILE) do |file|
      file.write(text)
    end

    assert_equal(text, XZ.decompress(File.open(LIVE_TEST_FILE, "rb"){|f| f.read}))
  end

end

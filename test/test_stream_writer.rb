# -*- coding: utf-8 -*-
gem "test-unit"

require "pathname"
require "test/unit"

require_relative "../lib/xz"

#For this testcase, please note that it isn’t possible to check
#whether the compressed string is equal to some other
#compressed string containing the same original text due to
#different compression options and/or different versions of
#liblzma. Hence, I can only test whether the re-decompressed
#result is equal to what I originally had.
class StreamWriterTest < Test::Unit::TestCase

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
      assert_compare(text.bytes.count, ">", writer.close)
      assert(writer.closed?, "Didn't close writer")
      assert_raises(IOError){writer.write("foo")}
    end

    assert_equal(text, XZ.decompress(File.open(LIVE_TEST_FILE, "rb"){|f| f.read}))
  end

  def test_stream_writer_open
    text = File.read(PLAIN_TEXT_FILE)
    
    XZ::StreamWriter.open(LIVE_TEST_FILE) do |file|
      file.write(text)
    end

    assert_equal(text, XZ.decompress(File.open(LIVE_TEST_FILE, "rb"){|f| f.read}))
  end

end

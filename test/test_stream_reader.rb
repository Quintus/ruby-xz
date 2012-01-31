# -*- coding: utf-8 -*-
gem "test-unit"

require "pathname"
require "test/unit"

require_relative "../lib/xz"

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

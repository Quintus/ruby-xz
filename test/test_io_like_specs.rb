gem "test-unit"

require "pathname"
require "test/unit"

require_relative "../lib/xz"

#This test checks whether or not we conform to the
#contracts enforced by the io-like gem.
#
#Note that this test checks a private API (the one exposed
#to the IO::Like library), hence the many calls to #send.
class IOLikeSpecsTest < Test::Unit::TestCase

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
    assert_compare(100_000, ">=", str.bytes.count)
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
    assert_compare(text.bytes.count, ">=", @writer.send(:unbuffered_write, text))
  end

end

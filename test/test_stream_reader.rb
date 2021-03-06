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

require_relative "common"

class StreamReaderTest < Minitest::Test

  TEST_DATA_DIR    = Pathname.new(__FILE__).dirname + "test-data"
  PLAIN_TEXT_FILE  = TEST_DATA_DIR + "lorem_ipsum.txt"
  XZ_TEXT_FILE     = TEST_DATA_DIR + "lorem_ipsum.txt.xz"
  XZ_ISO_TEXT_FILE = TEST_DATA_DIR + "iso88591.txt.xz"

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
      reader = XZ::StreamReader.new(file)
      reader.read
      reader.close
      assert(file.closed?, "Did not close file although expected!")
    end

    File.open(XZ_TEXT_FILE, "rb") do |file|
      reader = XZ::StreamReader.new(file)
      reader.read
      reader.finish
      assert(!file.closed?, "Closed file although not expected!")
    end

    reader = XZ::StreamReader.open(XZ_TEXT_FILE){|r| r.read}
    assert(reader.finished?, "Didn't finish stream!")
    assert(reader.instance_variable_get(:@delegate_io).closed?, "Didn't close internally created file!")

    reader = XZ::StreamReader.open(XZ_TEXT_FILE)
    reader.read
    reader.close
    assert(reader.instance_variable_get(:@delegate_io).closed?, "Didn't close internally created file!")

    reader = XZ::StreamReader.open(XZ_TEXT_FILE)
    reader.read
    reader.finish
    assert(!reader.instance_variable_get(:@delegate_io).closed?, "Closed internally created file although not expected!")

    File.open(XZ_TEXT_FILE, "rb") do |file|
      r = XZ::StreamReader.new(file)
      r.read(10)
      r.rewind
      assert(!file.closed?, "Closed handed IO during rewind!")
    end

    XZ::StreamReader.open(XZ_TEXT_FILE) do |r|
      r.read(10)
      r.rewind
      assert(!r.instance_variable_get(:@delegate_io).closed?, "Closed internal file during rewind")
    end

    # Test double closing (this should not raise)
    XZ::StreamReader.open(XZ_TEXT_FILE) do |r|
      r.close
    end

  end

  def test_finish
    File.open(XZ_TEXT_FILE, "rb") do |file|
      r = XZ::StreamReader.new(file)
      r.read
      assert_equal file, r.finish

      assert r.finished?, "Didn't finish despite of #finish"
      assert !file.closed?, "Closed wrapped file despite of #finish!"
    end

    file = nil
    XZ::StreamReader.open(XZ_TEXT_FILE){|r| r.read; file = r.finish}
    assert_kind_of File, file # Return value of #finish
    assert !file.closed?, "Closed wrapped file despite of #finish!"
    file.close # cleanup

    reader = XZ::StreamReader.open(XZ_TEXT_FILE)
    reader.read
    file = reader.finish
    assert_kind_of File, file
    assert !file.closed?, "Closed wrapped file despite of #finish!"
    file.close # cleanup
  end

  def test_open
    XZ::StreamReader.open(XZ_TEXT_FILE) do |reader|
      assert_equal(File.read(PLAIN_TEXT_FILE), reader.read)
    end

    File.open(XZ_TEXT_FILE, "rb") do |file|
      reader = XZ::StreamReader.new(file)
      assert_equal(File.read(PLAIN_TEXT_FILE), reader.read)
      reader.close
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

  def test_encodings
    enc1 = Encoding.default_external
    enc2 = Encoding.default_internal
    verb = $VERBOSE
    $VERBOSE = nil # Disable warnings, because setting
    # Encoding.default_{internal,external} generates a
    # warning. However, setting these is required to test
    # if they're properly honoured by ruby-xz.
    begin
      Encoding.default_external = Encoding::ISO_8859_1

      # Forced binary read must always yield BINARY
      XZ::StreamReader.open(XZ_ISO_TEXT_FILE) do |reader|
        str = reader.read(255)
        assert_equal Encoding::BINARY, str.encoding
      end

      # Now the external encoding needs to be detected
      XZ::StreamReader.open(XZ_ISO_TEXT_FILE) do |reader|
        str = reader.read
        assert_equal Encoding::ISO_8859_1, str.encoding
        assert str.valid_encoding?
      end

      # Request transcode
      XZ::StreamReader.open(XZ_ISO_TEXT_FILE, external_encoding: "ISO-8859-1", internal_encoding: "UTF-8") do |reader|
        str = reader.read
        assert_equal Encoding::UTF_8, str.encoding
        assert str.valid_encoding?
      end

      # Request transcode via default internal encoding
      Encoding.default_internal = Encoding::UTF_8
      XZ::StreamReader.open(XZ_ISO_TEXT_FILE) do |reader|
        str = reader.read
        assert_equal Encoding::UTF_8, str.encoding
        assert str.valid_encoding?
      end

      # Ensure getc does what it should when asked for multibyte chars
      XZ::StreamReader.open(XZ_ISO_TEXT_FILE) do |reader|
        assert_equal "B", reader.getc
        assert_equal "ä", reader.getc
        assert_equal "r", reader.getc
      end
    ensure
      # Reset to normal for further tests
      Encoding.default_external = enc1
      Encoding.default_internal = enc2
      $VERBOSE = verb
    end
  end

  def test_set_encoding
    reader = XZ::StreamReader.open(XZ_ISO_TEXT_FILE)

    reader.set_encoding "UTF-8"
    assert_equal Encoding::UTF_8, reader.external_encoding
    assert_equal nil, reader.internal_encoding

    reader.set_encoding "ISO-8859-1:UTF-8"
    assert_equal Encoding::ISO_8859_1, reader.external_encoding
    assert_equal Encoding::UTF_8, reader.internal_encoding

    reader.set_encoding Encoding::UTF_8
    assert_equal Encoding::UTF_8, reader.external_encoding
    assert_equal nil, reader.internal_encoding

    reader.set_encoding Encoding::UTF_8, Encoding::ISO_8859_1
    assert_equal Encoding::UTF_8, reader.external_encoding
    assert_equal Encoding::ISO_8859_1, reader.internal_encoding

    reader.set_encoding "ISO-8859-1", {:invalid => :replace, :replace => "?"}
    assert_equal Encoding::ISO_8859_1, reader.external_encoding
    assert_equal nil, reader.internal_encoding

    reader.set_encoding "ISO-8859-1", "UTF-8", {:invalid => :replace, :replace => "?"}
    assert_equal Encoding::ISO_8859_1, reader.external_encoding
    assert_equal Encoding::UTF_8, reader.internal_encoding

    reader.set_encoding "ISO-8859-1:UTF-8", {:invalid => :replace, :replace => "?"}
    assert_equal Encoding::ISO_8859_1, reader.external_encoding
    assert_equal Encoding::UTF_8, reader.internal_encoding

  end

end

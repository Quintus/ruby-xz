# -*- coding: utf-8 -*-
#--
# (The MIT license)
#
# Basic liblzma-bindings for Ruby.
#
# Copyright © 2018 Marvin Gülker
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

# An IO-like reader class for XZ-compressed data, allowing you to
# access XZ-compressed data as if it was a normal IO object, but
# please note you can’t seek in the data--this doesn’t make much
# sense anyway. Where would you want to seek? The plain or the XZ
# data?
#
# A StreamReader object actually wraps another IO object it reads
# the compressed data from; you can either pass this IO object directly
# to the ::new method, effectively allowing you to pass any IO-like thing
# you can imagine (just ensure it is readable), or you can pass a path
# to a filename to ::open, in which case StreamReader takes care of both
# opening and closing the file correctly.
#
# The wrapped IO object is automatically closed always correctly if
# you use the block-form instanciation, regardless of whether you
# passed a filename or an IO instance. To prevent that, call #finish,
# which will clear liblzma's buffers but leave the wrapped IO object
# open.
#
# ==Example
# In this example, we’re going to use ruby-xz together with the
# +archive-tar-minitar+ gem that allows to read tarballs. Used
# together, the two libraries allow us to read XZ-compressed tarballs.
#
#   require "xz"
#   require "archive/tar/minitar"
#
#   XZ::StreamReader.open("foo.tar.xz") do |txz|
#     # This automatically closes txz
#     Archive::Tar::Minitar.unpack(txz, "foo")
#   end
#
# Note that anything read from a StreamReader instance will *always* be
# tagged with the BINARY encoding. If that isn't what you want, you
# will need to call String#force_encoding on your received data.
class XZ::StreamReader < XZ::Stream

  attr_reader :options

  def self.open(filename, options = {})
    file = File.open(filename, "rb")
    reader = new(file, options)

    if block_given?
      begin
        return yield(reader)
      ensure
        # Close both delegate IO and reader.
        reader.close unless reader.finished?
      end
    end

    reader
  end

  def initialize(delegate_io, options = {})
    super(delegate_io)
    options[:memory_limit] ||= XZ::LibLZMA::UINT64_MAX
    options[:flags] ||= [:tell_unsupported_check]

    @options = options.freeze
    @readbuf = String.new

    allflags = options[:flags].reduce(0) do |val, flag|
      flag = XZ::LibLZMA::LZMA_DECODE_FLAGS[flag] || raise(ArgumentError, "Unknown flag #{flag}")
      val | flag
    end

    res = XZ::LibLZMA.lzma_stream_decoder(@lzma_stream.to_ptr,
                                      @options[:memory_limit],
                                      allflags)
    XZ::LZMAError.raise_if_necessary(res)
  end

  # Mostly like IO#read. The +length+ parameter refers to the amount
  # of decompressed bytes to read, not the amount of bytes to read
  # from the compressed data. That is, if you request a read of 50
  # bytes, you will receive a string with a maximum length of 50
  # bytes, regardless of how many bytes this was in compressed form.
  #
  # Return values are as per IO#read.
  def read(length = nil, outbuf = String.new)
    return "" if length == 0 # Shortcut; retval as per IO#read.

    # Note: Querying the underlying IO as early as possible allows to
    # have Ruby's own IO exceptions to bubble up.
    if length
      return nil if eof? # In line with IO#read

      # The user's request is in decompressed bytes, so it doesn't matter
      # how much is actually read from the compressed file.
      if @delegate_io.eof?
        data   = ""
        action = XZ::LibLZMA::LZMA_FINISH
      else
        data   = @delegate_io.read(XZ::CHUNK_SIZE)
        action = @delegate_io.eof? ? XZ::LibLZMA::LZMA_FINISH : XZ::LibLZMA::LZMA_RUN
      end

      lzma_code(data) { |decompressed| @readbuf << decompressed }

      # If the requested amount has been read, return it.
      # Also return if EOF has been reached. Note that
      # String#slice! will clear the string to an empty one
      # if `length' is greater than the string length.
      # If EOF is not yet reached, try reading and decompresing
      # more data.
      if @readbuf.bytesize >= length || @delegate_io.eof?
        result = @readbuf.slice!(0, length)
        @pos += result.bytesize
        return outbuf.replace(result)
      else
        return read(length, outbuf)
      end
    else
      # Read the entire file and decompress it into memory, returning it.
      while chunk = @delegate_io.read(XZ::CHUNK_SIZE)
        action = @delegate_io.eof? ? XZ::LibLZMA::LZMA_FINISH : XZ::LibLZMA::LZMA_RUN
        lzma_code(chunk, action) { |decompressed| @readbuf << decompressed }
      end

      @pos += @readbuf.bytesize
      outbuf.replace(@readbuf)
      @readbuf.clear
      return outbuf
    end
  end

  # Abort the current decompression process and reset everything
  # to the start so that reading from this reader will start over
  # from the beginning of the compressed data.
  #
  # The delegate IO has to support the #rewind method. Otherwise
  # like IO#rewind.
  def rewind
    super

    @readbuf.clear
    res = XZ::LibLZMA.lzma_stream_decoder(@lzma_stream.to_ptr,
                                      @options[:memory_limit],
                                      allflags)
    XZ::LZMAError.raise_if_necessary(res)

    0 # Mimic IO#rewind's return value
  end

  # Like IO#ungetbyte.
  def ungetbyte(obj)
    if obj.respond_to? :chr
      @readbuf.prepend(obj.chr)
    else
      @readbuf.prepend(obj.to_s)
    end
  end

  # Like IO#ungetc.
  def ungetc(str)
    @readbuf.prepend(str)
  end

  # Returns true if:
  #
  # 1. The underlying IO has reached EOF, and
  # 2. liblzma has returned everything it could make out of that.
  def eof?
    @delegate_io.eof? && @readbuf.empty?
  end

  def external_encoding
    Encoding::BINARY
  end

  def internal_encoding
    Encoding::BINARY
  end

  # Human-readable description
  def inspect
    "<#{self.class} pos=#{@pos} bufsize=#{@readbuf.bytesize} finished=#{@finished} closed=#{closed?} io=#{@delegate_io.inspect}>"
  end

end

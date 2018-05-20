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
# to a file to ::open, in which case StreamReader will open the path
# using Ruby's File class internally. If you use ::open's block form,
# the method will take care of properly closing both the liblzma
# stream and the File instance correctly.
class XZ::StreamReader < XZ::Stream

  # The memory limit configured for this lzma decoder.
  attr_reader :memory_limit

  # call-seq:
  #   open(filename [, kw]) → stream_reader
  #   open(filename [, kw]){|sr| ...} → stream_reader
  #
  # Open the given file and wrap a new instance around it with ::new.
  # If you use the block form, both the internally created File instance
  # and the liblzma stream will be closed automatically for you.
  #
  # === Parameters
  # [filename]
  #   Path to the file to open.
  # [sr (block argument)]
  #   The created StreamReader instance.
  #
  # See ::new for a description of the keyword parameters.
  #
  # === Return value
  # The newly created instance.
  #
  # === Remarks
  # Starting with version 1.0.0, the block form also returns the newly
  # created instance rather than the block's return value. This is
  # in line with Ruby's own GzipReader.open API.
  #
  # === Example
  #     # Normal usage
  #     XZ::StreamReader.open("myfile.txt.xz") do |xz|
  #       puts xz.read #=> I love Ruby
  #     end
  #
  #     # If you really need the File instance created internally:
  #     file = nil
  #     XZ::StreamReader.open("myfile.txt.xz") do |xz|
  #       puts xz.read #=> I love Ruby
  #       file = xz.finish # prevents closing
  #     end
  #     file.close # Now close it manually
  #
  #     # Or just don't use the block form:
  #     xz = XZ::StreamReader.open("myfile.txt.xz")
  #     puts xz.read #=> I love Ruby
  #     file = xz.finish
  #     file.close # Don't forget to close it manually (or use xz.close instead of xz.finish above).
  def self.open(filename, **args)
    file = File.open(filename, "rb")
    reader = new(file, **args)

    if block_given?
      begin
        yield(reader)
      ensure
        # Close both delegate IO and reader.
        reader.close unless reader.finished?
      end
    end

    reader
  end

  # Creates a new instance that is wrapped around the given IO object.
  #
  # === Parameters
  # ==== Positional parameters
  # [delegate_io]
  #   The underlying IO object to read the compressed data from.
  #   This IO object has to have been opened in binary mode,
  #   otherwise you are likely to receive exceptions indicating
  #   that the compressed data is corrupt.
  #
  # ==== Keyword arguments
  # [memory_limit (+UINT64_MAX+)]
  #   If not XZ::LibLZMA::UINT64_MAX, makes liblzma
  #   use no more memory than +memory_limit+ bytes.
  # [flags (<tt>[:tell_unsupported_check]</tt>)]
  #   Additional flags passed to liblzma (an array).
  #   Possible flags are:
  #
  #   [:tell_no_check]
  #     Spit out a warning if the archive hasn't an
  #     integrity checksum.
  #   [:tell_unsupported_check]
  #     Spit out a warning if the archive
  #     has an unsupported checksum type.
  #   [:concatenated]
  #     Decompress concatenated archives.
  # [external_encoding (Encoding.default_external)]
  #   Assume the decompressed data inside the XZ is encoded in
  #   this encoding. Defaults to Encoding.default_external,
  #   which in turn defaults to the environment.
  # [internal_encoding (Encoding.default_internal)]
  #   Request that the data found in the XZ file (which is assumed
  #   to be in the encoding specified by +external_encoding+) to
  #   be transcoded into this encoding. Defaults to Encoding.default_internal,
  #   which defaults to nil, which means to not transcode anything.
  #
  # === Return value
  # The newly created instance.
  #
  # === Remarks
  # The strings returned from the reader will be in the encoding specified
  # by the +internal_encoding+ parameter. If that parameter is nil (default),
  # then they will be in the encoding specified by +external_encoding+.
  #
  # This method used to accept a block in earlier versions. Since version 1.0.0,
  # this behaviour has been removed to synchronise the API with Ruby's own
  # GzipReader.open.
  #
  # This method doesn't close the underlying IO or the liblzma stream.
  # You need to call #finish or #close manually; see ::open for a method
  # that takes a block to automate this.
  #
  # === Example
  #     file = File.open("compressed.txt.xz", "rb") # Note binary mode
  #     xz = XZ::StreamReader.open(file)
  #     puts xz.read #=> I love Ruby
  #     xz.close # closes both `xz' and `file'
  #
  #     file = File.open("compressed.txt.xz", "rb") # Note binary mode
  #     xz = XZ::StreamReader.open(file)
  #     puts xz.read #=> I love Ruby
  #     xz.finish # closes only `xz'
  #     file.close # Now close `file' manually
  def initialize(delegate_io, memory_limit: XZ::LibLZMA::UINT64_MAX, flags: [:tell_unsupported_check], external_encoding: nil, internal_encoding: nil)
    super(delegate_io)
    raise(ArgumentError, "When specifying the internal encoding, the external encoding must also be specified") if internal_encoding && !external_encoding
    raise(ArgumentError, "Memory limit out of range") unless memory_limit > 0 && memory_limit <= XZ::LibLZMA::UINT64_MAX

    @memory_limit = memory_limit
    @readbuf = String.new
    @readbuf.force_encoding(Encoding::BINARY)

    if external_encoding
      encargs = []
      encargs << external_encoding
      encargs << internal_encoding if internal_encoding
      set_encoding(*encargs)
    end

    @allflags = flags.reduce(0) do |val, flag|
      flag = XZ::LibLZMA::LZMA_DECODE_FLAGS[flag] || raise(ArgumentError, "Unknown flag #{flag}")
      val | flag
    end

    res = XZ::LibLZMA.lzma_stream_decoder(@lzma_stream.to_ptr,
                                      @memory_limit,
                                      @allflags)
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
    return "".force_encoding(Encoding::BINARY) if length == 0 # Shortcut; retval as per IO#read.

    # Note: Querying the underlying IO as early as possible allows to
    # have Ruby's own IO exceptions to bubble up.
    if length
      return nil if eof? # In line with IO#read
      outbuf.force_encoding(Encoding::BINARY) # As per IO#read docs

      # The user's request is in decompressed bytes, so it doesn't matter
      # how much is actually read from the compressed file.
      if @delegate_io.eof?
        data   = ""
        action = XZ::LibLZMA::LZMA_FINISH
      else
        data   = @delegate_io.read(XZ::CHUNK_SIZE)
        action = @delegate_io.eof? ? XZ::LibLZMA::LZMA_FINISH : XZ::LibLZMA::LZMA_RUN
      end

      lzma_code(data, action) { |decompressed| @readbuf << decompressed }

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

      # Apply encoding conversion.
      # First, tag the read data with the external encoding.
      @readbuf.force_encoding(@external_encoding)

      # Now, transcode it to the internal encoding if that was requested.
      # Otherwise return it with the external encoding as-is.
      if @internal_encoding
        @readbuf.encode!(@internal_encoding, @transcode_options)
        outbuf.force_encoding(@internal_encoding)
      else
        outbuf.force_encoding(@external_encoding)
      end

      outbuf.replace(@readbuf)
      @readbuf.clear
      @readbuf.force_encoding(Encoding::BINARY) # Back to binary mode for further reading

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
                                      @memory_limit,
                                      @allflags)
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

  # Human-readable description
  def inspect
    "<#{self.class} pos=#{@pos} bufsize=#{@readbuf.bytesize} finished=#{@finished} closed=#{closed?} io=#{@delegate_io.inspect}>"
  end

end

# -*- coding: utf-8 -*-
# (The MIT license)
#
# Basic liblzma-bindings for Ruby.
#
# Copyright © 2012 Marvin Gülker
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
# to a filename to ::new, in which case StreamReader takes care of both
# opening and closing the file correctly. You can even take it one step
# further and use the block form of ::new which will automatically call
# the #close method for you after the block finished. However, if you pass
# an IO, remember you have to close:
#
# 1. The StreamReader instance.
# 2. The IO object you passed to ::new.
#
# Do it <b>in exactly that order</b>, otherwise you may lose data.
#
# See the +io-like+ gem’s documentation for the IO-reading methods
# available for this class (although you’re probably familiar with
# them through Ruby’s own IO class ;-)).
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
class XZ::StreamReader < XZ::Stream

  # The memory limit you set for this reader (in ::new).
  attr_reader :memory_limit

  # The flags you set for this reader (in ::new).
  attr_reader :flags

  # call-seq:
  #   new(delegate, memory_limit = XZ::LibLZMA::UINT64_MAX, flags = [:tell_unsupported_check])  → a_stream_reader
  #   open(delegate, memory_limit = XZ::LibLZMA::UINT64_MAX, flags = [:tell_unsupported_check]) → a_stream_reader
  #
  # Creates a new StreamReader instance. If you pass an IO,
  # remember you have to close *both* the resulting instance
  # (via the #close method) and the IO object you pass to flush
  # any internal buffers in order to be able to read all decompressed
  # data.
  #
  # === Parameters
  #
  # [delegate]
  #   An IO object to read the data from, or a path
  #   to a file to open. If you’re in an urgent need to
  #   pass a plain string, use StringIO from Ruby’s
  #   standard library. If this is an IO, it must be
  #   opened for reading.
  #
  # The other parameters are identical to what the XZ::decompress_stream
  # method expects.
  #
  # === Return value
  #
  # The newly created instance.
  #
  # === Example
  #
  #   # Wrap it around a file
  #   f = File.open("foo.xz")
  #   r = XZ::StreamReader.new(f)
  #
  #   # Ignore any XZ checksums (may result in invalid
  #   # data being read!)
  #   File.open("foo.xz") do |f|
  #     r = XZ::StreamReader.new(f, XZ::LibLZMA::UINT64_MAX, [:tell_no_check]
  #   end
  #
  #   # Let StreamReader handle file closing
  #   # automatically
  #   XZ::StreamReader.new("myfile.xz"){|r| r.raed}
  def initialize(delegate, memory_limit = XZ::LibLZMA::UINT64_MAX, flags = [:tell_unsupported_check])
    raise(ArgumentError, "Invalid memory limit set!") unless (0..XZ::LibLZMA::UINT64_MAX).include?(memory_limit)
    flags.each do |flag|
      raise(ArgumentError, "Unknown flag #{flag}!") unless [:tell_no_check, :tell_unsupported_check, :tell_any_check, :concatenated].include?(flag)
    end

    if delegate.respond_to?(:to_io)
      super(delegate)
    else
      @file = File.open(delegate, "rb")
      super(@file)
    end

    @memory_limit = memory_limit
    @flags        = flags

    res = XZ::LibLZMA.lzma_stream_decoder(@lzma_stream,
                                          @memory_limit,
                                          @flags.inject(0){|val, flag| val | XZ::LibLZMA.const_get(:"LZMA_#{flag.to_s.upcase}")})
    XZ::LZMAError.raise_if_necessary(res)

    @input_buffer_p = FFI::MemoryPointer.new(XZ::CHUNK_SIZE)

    # These two are only used in #unbuffered read.
    @__lzma_finished = false
    @__lzma_action   = nil

    if block_given?
      begin
        yield(self)
      ensure
        close unless closed?
      end
    end
  end
  self.class.send(:alias_method, :open, :new)

  # Closes this StreamReader instance. Don’t use it afterwards
  # anymore.
  #
  # === Return value
  #
  # The total number of bytes decompressed.
  #
  # === Example
  #
  #   r.close #=> 6468
  #
  # === Remarks
  #
  # If you passed an IO to ::new, this method doesn’t close it, so
  # you have to close it yourself.
  def close
    super

    # Close the XZ stream
    res = XZ::LibLZMA.lzma_end(@lzma_stream.pointer)
    XZ::LZMAError.raise_if_necessary(res)

    #If we created a File object, close this as well.
    @file.close if @file

    # Return the number of bytes written in total.
    @lzma_stream[:total_out]
  end

  # call-seq:
  #   pos()  → an_integer
  #   tell() → an_integer
  #
  # Total number of output bytes provided to you yet.
  def pos
    @lzma_stream[:total_out]
  end
  alias tell pos

  # Instrcuts liblzma to immediately stop decompression,
  # rewinds the wrapped IO object and reinitalizes the
  # StreamReader instance with the same values passed
  # originally to the ::new method. The wrapped IO object
  # must support the +rewind+ method for this method to
  # work; if it doesn’t, this method throws an IOError.
  # After the exception was thrown, the StreamReader instance
  # is in an unusable state. You cannot continue using it
  # (don’t call #close on it either); close the wrapped IO
  # stream and create another instance of this class.
  #
  # === Raises
  #
  # [IOError]
  #   The wrapped IO doesn’t support rewinding.
  #   Do not use the StreamReader instance anymore
  #   after receiving this exception.
  #
  # ==Remarks
  #
  # I don’t really like this method, it uses several dirty
  # tricks to circumvent both io-like’s and liblzma’s control
  # mechanisms. I only implemented this because the
  # <tt>archive-tar-minitar</tt> gem calls this method when
  # unpacking a TAR archive from a stream.
  def rewind
    # HACK: Wipe all data from io-like’s internal read buffer.
    # This heavily relies on io-like’s internal structure.
    # Be always sure to test this when a new version of
    # io-like is released!
    __io_like__internal_read_buffer.clear

    # Forcibly close the XZ stream (internally frees it!)
    res = XZ::LibLZMA.lzma_end(@lzma_stream.pointer)
    XZ::LZMAError.raise_if_necessary(res)

    # Rewind the wrapped IO
    begin
      @delegate_io.rewind
    rescue => e
      raise(IOError, "Delegate IO failed to rewind! Original message: #{e.message}")
    end

    # Reinitialize everything. Note this doesn’t affect @file as it
    # is already set and stays so (we don’t pass a filename here,
    # but rather an IO)
    initialize(@delegate_io, @memory_limit, @flags)
  end

  # NO, you CANNOT seek in this object!!
  # io-like’s default behaviour is to raise Errno::ESPIPE
  # when calling a non-defined seek, which is not what some
  # libraries such as RubyGem’s TarReader expect (they expect
  # a NoMethodError/NameError instead).
  undef seek

  private

  # Called by io-like’s read methods such as #read. Does the heavy work
  # of feeding liblzma the compressed data and reading the returned
  # uncompressed data.
  def unbuffered_read(length)
    raise(EOFError, "Input data completely processed!") if @__lzma_finished

    output_buffer_p = FFI::MemoryPointer.new(length) # User guarantees that this fits into RAM

    @lzma_stream[:next_out]  = output_buffer_p
    @lzma_stream[:avail_out] = output_buffer_p.size

    loop do
      # DON’T overwrite any not yet consumed input from any previous
      # run! Instead, wait until the last input data is entirely
      # consumed, then provide new data.
      # TODO: Theoretically, one could move the remaining data to the
      # beginning of the pointer and fill the rest with new data,
      # being a tiny bit more performant.
      if @lzma_stream[:avail_in].zero?
        compressed_data = @delegate_io.read(@input_buffer_p.size) || "" # nil at EOS → ""
        @input_buffer_p.write_string(compressed_data)
        @lzma_stream[:next_in] = @input_buffer_p
        @lzma_stream[:avail_in] = binary_size(compressed_data)

        # Now check if we’re at the last bytes of data and set accordingly the
        # LZMA-action to carry out (for any subsequent runs until
        # all input data has been consumed and the above condition
        # is triggered again).
        #
        # The @__lzma_action variable is only used in this method
        # and is _not_ supposed to be accessed from any other method.
        if compressed_data.empty?
          @__lzma_action = XZ::LibLZMA::LZMA_ACTION[:lzma_finish]
        else
          @__lzma_action = XZ::LibLZMA::LZMA_ACTION[:lzma_run]
        end
      end

      res = XZ::LibLZMA.lzma_code(@lzma_stream.pointer, @__lzma_action)

      # liblzma signals LZMA_BUF_ERROR when the output buffer is
      # completely filled, which means we can return now.
      # When it signals LZMA_STREAM_END, the buffer won’t be filled
      # completely anymore as the whole input data has been consumed.
      if res == XZ::LibLZMA::LZMA_RET[:lzma_buf_error]
        # @lzma_stream[:avail_out] holds the number of free bytes _behind_
        # the produced output!
        return output_buffer_p.read_string(output_buffer_p.size - @lzma_stream[:avail_out])
      elsif res == XZ::LibLZMA::LZMA_RET[:lzma_stream_end]
        # @__lzma_finished is not supposed to be used outside this method!
        @__lzma_finished = true
        return output_buffer_p.read_string(output_buffer_p.size - @lzma_stream[:avail_out])
      else
        XZ::LZMAError.raise_if_necessary(res)
      end
    end #loop

  rescue XZ::LZMAError => e
    raise(SystemCallError, e.message)
  end

end

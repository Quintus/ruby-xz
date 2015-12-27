# -*- coding: utf-8 -*-
#--
# (The MIT license)
#
# Basic liblzma-bindings for Ruby.
#
# Copyright © 2012, 2015 Marvin Gülker
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

# An IO-like writer class for XZ-compressed data, allowing you to
# write uncompressed data to a stream which ends up as compressed data
# in a wrapped stream such as a file.
#
# A StreamWriter object actually wraps another IO object it writes the
# XZ-compressed data to. Here’s an ASCII art image to demonstrate way
# data flows when using StreamWriter to write to a compressed file:
#
#           +----------------+  +------------+
#   YOUR  =>|StreamWriter's  |=>|Wrapped IO's|=> ACTUAL
#   DATA  =>|internal buffers|=>|buffers     |=>  FILE
#           +----------------+  +------------+
#
# This graphic also illustrates why it is unlikely to see written data
# directly appear in the file on your harddisk; the data is cached at
# least twice before it actually gets written out. Regarding file
# closing that means that before you can be sure any pending data has
# been written to the file you have to close both the StreamWriter
# instance and then the wrapped IO object (in *exactly* that order,
# otherwise data loss and unexpected exceptions may occur!).
#
# As it might be tedious to always remember the correct closing order,
# it’s possible to pass a filename to the ::open method. In this case,
# StreamWriter will open the file internally and also takes care
# closing it when you call the #close method.
#
# *WARNING*: The closing behaviour described above is subject to
# change in the next major version. In the future, wrapped IO
# objects are automatically closed always, regardless of whether you
# passed a filename or an IO instance. This is to sync the API with
# Ruby’s own Zlib::GzipWriter. To retain the old behaviour, call
# the #finish method (which is also in sync with the Zlib API).
#
# See the +io-like+ gem’s documentation for the IO-writing methods
# available for this class (although you’re probably familiar with
# them through Ruby’s own IO class ;-)).
#
# == Example
#
# Together with the <tt>archive-tar-minitar</tt> gem, this library
# can be used to create XZ-compressed TAR archives (these commonly
# use a file extension of <tt>.tar.xz</tt> or rarely <tt>.txz</tt>).
#
#   XZ::StreamWriter.open("foo.tar.xz") do |txz|
#     # This automatically closes txz
#     Archive::Tar::Minitar.pack("foo", txz)
#   end
class XZ::StreamWriter < XZ::Stream

  # call-seq:
  #  new(delegate, compression_level = 6, opts = {}) → writer
  #  new(delegate, compression_level = 6, opts = {}){|writer| …} → obj
  #
  # Creates a new StreamWriter instance. The block form automatically
  # calls the #close method when the block has finished executing.
  #
  # === Parameters
  # [delegate]
  #   An IO object to write the data to
  #
  # [compression_level (6)]
  #   Compression strength. Higher values indicate a smaller result,
  #   but longer compression time. Maximum is 9.
  #
  # [opts]
  #   Options hash. Possible values are (defaults indicated in
  #   parantheses):
  #
  #   [:check (:crc64)]
  #     The checksum algorithm to use for verifying
  #     the data inside the archive. Possible values are:
  #     * :none
  #     * :crc32
  #     * :crc64
  #     * :sha256
  #
  #   [:extreme (false)]
  #     Tries to get the last bit out of the compression.
  #     This may succeed, but you can end up with *very*
  #     long computation times.
  #
  # [writer]
  #   Block argument. self of the new instance.
  #
  # === Return value
  #
  # The block form returns the block’s last expression, the nonblock
  # form returns the newly created instance.
  #
  # === Deprecations
  #
  # The old API for this method as it was documented in version 0.2.1
  # still works, but is deprecated. Please change to the new API as
  # soon as possible.
  #
  # *WARNING*: The closing behaviour of the block form is subject to
  # upcoming change. In the next major release the wrapped IO *will*
  # be automatically closed, unless you call #finish to prevent that.
  #
  # === Example
  #
  #   # Wrap it around a file
  #   f = File.open("data.xz")
  #   w = XZ::StreamWriter.new(f)
  #
  #   # Use SHA256 as the checksum and use a higher compression level
  #   # than the default (6)
  #   f = File.open("data.xz")
  #   w = XZ::StreamWriter.new(f, 8, :check => :sha256)
  #
  #   # Instruct liblzma to use ultra-really-high compression
  #   # (may take eternity)
  #   f = File.open("data.xz")
  #   w = XZ::StreamWriter.new(f, 9, :extreme => true)
  def initialize(delegate, compression_level = 6, *args, &block)
    if delegate.respond_to?(:to_io)
      # Correct use with IO
      super(delegate.to_io)
      @autoclose = false
    else
      # Deprecated use of filename
      XZ.deprecate "Calling XZ::StreamWriter.new with a filename is deprecated, use XZ::StreamWriter.open instead"

      @autoclose = true
      super(File.open(delegate, "wb"))
    end

    # Flag for #finish method
    @finish = false

    opts = {}
    if args[0].kind_of?(Hash) # New API
      opts = args[0]
      opts[:check] ||= :crc64
      opts[:extreme] ||= false
    else # Old API
      # no arguments may also happen in new API
      unless args.empty?
        XZ.deprecate "Calling XZ::StreamWriter withm ore than 2 explicit arguments is deprecated, use options hash instead."
      end

      opts[:check] = args[0] || :crc64
      opts[:extreme] = args[1] || false
    end

    # TODO: Check argument validity...

    # Initialize the internal LZMA stream for encoding
    res = XZ::LibLZMA.lzma_easy_encoder(@lzma_stream.pointer,
                                  compression_level | (opts[:extreme] ? XZ::LibLZMA::LZMA_PRESET_EXTREME : 0),
                                  XZ::LibLZMA::LZMA_CHECK[:"lzma_check_#{opts[:check]}"])
    XZ::LZMAError.raise_if_necessary(res)

    if block_given?
      begin
        yield(self)
      ensure
        close unless closed?
      end
    end
  end

  # call-seq:
  #   open(filename, compression_level = 6, opts = {}) → writer
  #   open(filename, compression_level = 6, opts = {}){|writer| …} → obj
  #
  # Opens a file from disk and wraps an XZ::StreamWriter instance
  # around the resulting file IO object. This is a convenience method
  # mostly equivalent to
  #
  #   file = File.open(filename, "wb")
  #   writer = XZ::StreamWriter.new(file, compression_level, opts)
  #
  # , except that you don’t have to explicitely close the File
  # instance, this is done automatically for you when you call #close.
  # Beware the Deprecations section in this regard.
  #
  # === Parameters
  #
  # [filename]
  #   Path to a file on the disk to open. This file should exist and be
  #   writable, otherwise you may get Errno exceptions.
  #
  # [opts]
  #   Options hash. See ::new for a description of the possible
  #   options.
  #
  # [writer]
  #   Block argument. self of the new instance.
  #
  # === Return value
  #
  # The block form returns the blocks last expression, the nonblock
  # form returns the newly created XZ::StreamWriter instance.
  #
  # === Deprecations
  #
  # In the API up to and including version 0.2.1 this method was an
  # alias for ::new. This continues to work for now, but using it
  # as an alias for ::new is deprecated. The next major version will
  # only accept a string as a parameter for this method.
  #
  # *WARNING*: Future versions of ruby-xz will always close the
  # wrapped IO, regardless of whether you pass in your own IO or use
  # this convenience method, unless you call #finish to prevent that.
  #
  # === Example
  #
  #   w = XZ::StreamWriter.new("compressed_data.xz")
  def self.open(filename, compression_level = 6, *args, &block)
    if filename.respond_to?(:to_io)
      # Deprecated use of IO
      XZ.deprecate "Calling XZ::StreamWriter.open with an IO is deprecated, use XZ::StreamReader.new instead."
      new(filename.to_io, compression_level, *args, &block)
    else
      # Correct use with filename
      file = File.open(filename, "wb")

      obj = new(file, compression_level, *args)
      obj.instance_variable_set(:@autoclose, true) # Only needed during deprecation phase, see #close

      if block_given?
        begin
          block.call(obj)
        ensure
          obj.close unless obj.closed?
        end
      else
        obj
      end
    end
  end

  # Closes this StreamWriter instance and flushes all internal buffers.
  # Don’t use it afterwards anymore.
  #
  # === Return value
  #
  # The total number of bytes written, i.e. the size of the compressed
  # data.
  #
  # === Example
  #
  #   w.close #=> 424
  #
  # === Remarks
  #
  # If you passed an IO object to ::new, this method doesn’t close it,
  # you have to do that yourself.
  #
  # *WARNING*: The next major release will change this behaviour.
  # In the future, the wrapped IO object will always be closed.
  # Use the #finish method for keeping it open.
  def close
    super

    #1. Close the current block ("file") (an XZ stream may actually include
    #   multiple compressed files, which however is not supported by
    #   this library). For this we have to tell liblzma that
    #   the next bytes we pass to it are the last bytes (by means of
    #   the FINISH action). Just that we don’t pass any new input ;-)

    output_buffer_p         = FFI::MemoryPointer.new(XZ::CHUNK_SIZE)

    # Get any pending data (LZMA_FINISH causes libzlma to flush its
    # internal buffers) and write it out to our wrapped IO.
    loop do
      @lzma_stream[:next_out]  = output_buffer_p
      @lzma_stream[:avail_out] = output_buffer_p.size

      res = XZ::LibLZMA.lzma_code(@lzma_stream.pointer, XZ::LibLZMA::LZMA_ACTION[:lzma_finish])
      XZ::LZMAError.raise_if_necessary(res)

      @delegate_io.write(output_buffer_p.read_string(output_buffer_p.size - @lzma_stream[:avail_out]))

      break unless @lzma_stream[:avail_out] == 0
    end

    # 2. Close the whole XZ stream.
    res = XZ::LibLZMA.lzma_end(@lzma_stream.pointer)
    XZ::LZMAError.raise_if_necessary(res)

    unless @finish
      # New API: Close the wrapped IO
      #@delegate_io.close

      # Old API:
      # 2b. If we wrapped a file automatically, close it.
      if @autoclose
        @delegate_io.close
      else
        XZ.deprecate "XZ::StreamWriter#close will automatically close the wrapped IO in the future. Use #finish to prevent that."
      end
    end

    # 3. Return the number of bytes written in total.
    @lzma_stream[:total_out]
  end

  # If called in the block form of ::new or ::open, prevents the
  # wrapped IO from being closed, only the LZMA stream is closed
  # then. If called outside the block form of ::new and open, behaves
  # like #close, but only closes the underlying LZMA stream. The
  # wrapped IO object is kept open.
  #
  # === Return value
  #
  # Returns the wrapped IO object. This allows you to wire the File
  # instance out of a StreamReader instance that was created with
  # ::open.
  #
  # === Example
  #
  #   # Nonblock form
  #   f = File.open("foo.xz", "wb")
  #   w = XZ::StreamReader.new(f)
  #   # ...
  #   w.finish
  #   # f is still open here!
  #
  #   # Block form
  #   f = XZ::StreamReader.open("foo.xz") do |w|
  #     # ...
  #     w.finish
  #   end
  #   # f now is an *open* File instance of mode "wb".
  def finish
    # Do not close wrapped IO object in #close
    @finish = true
    close

    @delegate_io
  end

  # call-seq:
  #   pos()  → an_integer
  #   tell() → an_integer
  #
  # Total number of input bytes read so far from what you supplied to
  # any writer method.
  def pos
    @lzma_stream[:total_in]
  end
  alias tell pos

  private

  # Called by io-like’s write methods such as #write. Does the heavy
  # work of feeding liblzma the uncompressed data and reading the
  # returned compressed data.
  def unbuffered_write(data)
    output_buffer_p = FFI::MemoryPointer.new(XZ::CHUNK_SIZE)
    input_buffer_p  = FFI::MemoryPointer.from_string(data) # This adds a terminating NUL byte we don’t want to compress!

    @lzma_stream[:next_in]  = input_buffer_p
    @lzma_stream[:avail_in] = input_buffer_p.size - 1 # Don’t hand the terminating NUL

    loop do
      @lzma_stream[:next_out]  = output_buffer_p
      @lzma_stream[:avail_out] = output_buffer_p.size

      # Compress the data
      res = XZ::LibLZMA.lzma_code(@lzma_stream.pointer, XZ::LibLZMA::LZMA_ACTION[:lzma_run])
      XZ::LZMAError.raise_if_necessary(res) # TODO: Warnings

      # Write the compressed data
      result = output_buffer_p.read_string(output_buffer_p.size - @lzma_stream[:avail_out])
      @delegate_io.write(result)

      # Loop until liblzma ate the whole data.
      break if @lzma_stream[:avail_in] == 0
    end

    binary_size(data)
  rescue XZ::LZMAError => e
    raise(SystemCallError, e.message)
  end

end

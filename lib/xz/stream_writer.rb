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

#An IO-like writer class for XZ-compressed data, allowing you to write
#uncompressed data to a stream which ends up as compressed data in
#a wrapped stream such as a file.
#
#A StreamWriter object actually wraps another IO object it writes the
#XZ-compressed data to. Here’s an ASCII art image to demonstrate
#way data flows when using StreamWriter to write to a compressed
#file:
#
#          +----------------+  +------------+
#  YOUR  =>|StreamWriter's  |=>|Wrapped IO's|=> ACTUAL
#  DATA  =>|internal buffers|=>|buffers     |=>  FILE
#          +----------------+  +------------+
#
#This graphic also illustrates why it is unlikely to see written
#data directly appear in the file on your harddisk; the data is
#cached at least twice before it actually gets written out. Regarding
#file closing that means that before you can be sure any pending data
#has been written to the file you have to close both the StreamWriter
#instance and then the wrapped IO object (in *exactly* that order, otherwise
#data loss and unexpected exceptions may occur!).
#
#As it might be tedious to always remember the correct closing order,
#it’s possible to pass a filename to the ::new method. In this case,
#StreamWriter will open the file internally and also takes care closing
#it when you call the #close method.
#
#See the +io-like+ gem’s documentation for the IO-writing methods
#available for this class (although you’re probably familiar with
#them through Ruby’s own IO class ;-)).
#
#==Example
#Together with the <tt>archive-tar-minitar</tt> gem, this library
#can be used to create XZ-compressed TAR archives (these commonly
#use a file extension of <tt>.tar.xz</tt> or rarely <tt>.txz</tt>).
#
#  XZ::StreamWriter.open("foo.tar.xz") do |txz|
#    # This automatically closes txz
#    Archive::Tar::Minitar.pack("foo", txz)
#  end
class XZ::StreamWriter < XZ::Stream

  #call-seq:
  # open(delegate, compression_level = 6, check = :crc64, extreme = false) → a_stream_writer
  # new(delegate, compression_level = 6, check = :crc64, extreme = false)  → a_stream_writer
  #
  #Creates a new StreamWriter instance. The block form automatically
  #calls the #close method when the block has finished executing.
  #==Parameters
  #[delegate] An IO object to write the data to or a filename
  #           which will be opened internally. If you pass an IO,
  #           the #close method won’t close the passed IO object;
  #           if you passed a filename, the created internal file
  #           of course gets closed.
  #The other parameters are identical to what the XZ::compress_stream
  #method expects.
  #==Return value
  #The newly created instance.
  #==Example
  #  # Wrap it around a file
  #  f = File.open("data.xz")
  #  w = XZ::StreamWriter.new(f)
  #
  #  # Use SHA256 as the checksum and use a higher compression level
  #  # than the default (6)
  #  f = File.open("data.xz")
  #  w = XZ::StreamWriter.new(f, 8, :sha256)
  #
  #  # Instruct liblzma to use ultra-really-high compression
  #  # (may take eternity)
  #  f = File.open("data.xz")
  #  w = XZ::StreamWriter.new(f, 9, :crc64, true)
  #
  #  # Passing a filename
  #  w = XZ::StreamWriter.new("compressed_data.xz")
  def initialize(delegate, compression_level = 6, check = :crc64, extreme = false)
    if delegate.respond_to?(:to_io)
      super(delegate)
    else
      @file = File.open(delegate, "wb")
      super(@file)
    end
    
    # Initialize the internal LZMA stream for encoding
    res = XZ::LibLZMA.lzma_easy_encoder(@lzma_stream.pointer, 
                                  compression_level | (extreme ? XZ::LibLZMA::LZMA_PRESET_EXTREME : 0),
                                  XZ::LibLZMA::LZMA_CHECK[:"lzma_check_#{check}"])
    XZ::LZMAError.raise_if_necessary(res)

    if block_given?
      begin
        yield(self)
      ensure
        close
      end
    end
  end
  self.class.send(:alias_method, :open, :new)

  #Closes this StreamWriter instance and flushes all internal buffers.
  #Don’t use it afterwards anymore.
  #==Return vaule
  #The total number of bytes written, i.e. the size of the compressed
  #data.
  #==Example
  #  w.close #=> 424
  #==Remarks
  #If you passed an IO object to ::new, this method doesn’t close it,
  #you have to do that yourself.
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

    #2. Close the whole XZ stream.
    res = XZ::LibLZMA.lzma_end(@lzma_stream.pointer)
    XZ::LZMAError.raise_if_necessary(res)

    #2b. If we wrapped a file automatically, close it.
    @file.close if @file

    #3. Return the number of bytes written in total.
    @lzma_stream[:total_out]
  end

  #call-seq:
  #  pos()  → an_integer
  #  tell() → an_integer
  #
  #Total number of input bytes read so far from what you
  #supplied to any writer method.
  def pos
    @lzma_stream[:total_in]
  end
  alias tell pos

  private

  #Called by io-like’s write methods such as #write. Does the heavy
  #work of feeding liblzma the uncompressed data and reading the
  #returned compressed data.
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

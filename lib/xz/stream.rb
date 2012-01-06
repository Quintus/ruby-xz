# -*- coding: utf-8 -*-

class XZ::Stream
  include IO::Like

  def self.open(io_or_filename)
    # If we got an IO, use it. Otherwise, convert it to
    # a string and use it as a pathname to open. Then, use
    # the resulting File object.
    if io_or_filename.respond_to?(:to_io)
      stream = new(io_or_filename.to_io)
    else
      file   = File.open(io_or_fileame.to_s) # Closed via method-ensure
      stream = new(file)
    end

    # If we got a block, ensure the Stream instance is closed after
    # the block has been left. Otherwise, behave the same way as ::new.
    if block_given?
      begin
        yield
      ensure
        stream.close unless stream.closed?
      end
    end
  ensure
    file.close
  end

  def initialize(delegate_io)
    @delegate_io    = delegate_io
    @lzma_stream    = XZ::LZMAStream.new
    @input_buffer_p = FFI::MemoryPointer.new(XZ::CHUNK_SIZE)
    @closed         = false
  end

  def close
    super
    
    #1. Close the current block ("file") (an XZ stream may actually include
    #   multiple compressed files, which however is not supported by
    #   this library). For this we have to tell liblzma that
    #   the next bytes we pass to it are the last bytes (by means of
    #   the FINISH action). However, when this method is called all
    #   data is already compressed, so we just tell liblzma that
    #   there are exactly 0 bytes we want to compress before finishing
    #   the file.
    
    output_buffer_p         = FFI::MemoryPointer.new(XZ::CHUNK_SIZE)
    @lzma_stream[:next_in]  = nil # We can pass a NULL pointer here b/c we make libzlma...
    @lzma_stream[:avail_in] = 0   #...only read 0 bytes from that pointer
    
    # Get any pending data (LZMA_FINISH causes libzlma to flush its
    # internal buffers) and write it out to our wrapped IO.
    loop do
      @lzma_stream[:next_out]  = output_buffer_p
      @lzma_stream[:avail_out] = output_buffer_p.size
      
      res = XZ::LibLZMA.lzma_code(@lzma_stream.pointer, XZ::LibLZMA::LZMA_ACTION[:lzma_finish])
      XZ::LZMAError.raise_if_necessary(res)
      
      @delegate_io.write(output_buffer_p.read_string(output_buffer_p.size - @lzma_stream[:avail_out]))
      
      break if res == XZ::LibLZMA::LZMA_RET[:lzma_stream_end]
    end

    #2. Close the whole XZ stream.
    res = XZ::LibLZMA.lzma_end(@lzma_stream.pointer)
    XZ::LZMAError.raise_if_necessary(res)

    #3. Return the number of bytes written in total.
    @lzma_stream[:total_out]
  end


  private

  #This method returns the size of +str+ in bytes.
  def binary_size(str)
    #Believe it or not, but this is faster than str.bytes.to_a.size.
    #I benchmarked it, and it is as twice as fast.
    if str.respond_to? :force_encoding
      str.dup.force_encoding("BINARY").size
    else
      str.bytes.to_a.size
    end
  end

end

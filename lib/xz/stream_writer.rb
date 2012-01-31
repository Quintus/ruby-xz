# -*- coding: utf-8 -*-

class XZ::StreamWriter < XZ::Stream

  def initialize(delegate_io, compression_level = 6, check = :crc64, extreme = false)
    super(delegate_io)
    
    # Initialize the internal LZMA stream for encoding
    res = XZ::LibLZMA.lzma_easy_encoder(@lzma_stream.pointer, 
                                  compression_level | (extreme ? XZ::LibLZMA::LZMA_PRESET_EXTREME : 0),
                                  XZ::LibLZMA::LZMA_CHECK[:"lzma_check_#{check}"])
    XZ::LZMAError.raise_if_necessary(res)
  end

  def close
    super
    
    #1. Close the current block ("file") (an XZ stream may actually include
    #   multiple compressed files, which however is not supported by
    #   this library). For this we have to tell liblzma that
    #   the next bytes we pass to it are the last bytes (by means of
    #   the FINISH action). However, when this method is called all
    #   data has already been handed over, so we just tell liblzma that
    #   there are exactly 0 bytes we want to compress before finishing
    #   the file.
    
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

    #3. Return the number of bytes written in total.
    @lzma_stream[:total_out]
  end

  private
  
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

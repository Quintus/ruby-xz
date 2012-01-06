class XZ::StreamWriter < XZ::Stream

  def initialize(delegate_io, compression_level = 6, check = :crc64, extreme = false)
    super(delegate_io)
    
    # Initialize the internal LZMA stream for encoding
    res = XZ::LibLZMA.lzma_easy_encoder(@lzma_stream.pointer, 
                                  compression_level | (extreme ? XZ::LibLZMA::LZMA_PRESET_EXTREME : 0),
                                  XZ::LibLZMA::LZMA_CHECK[:"lzma_check_#{check}"])
    XZ::LZMAError.raise_if_necessary(res)
  end

  private
  
  def unbuffered_write(data)
    input_buffer_p  = FFI::MemoryPointer.from_string(data)
    output_buffer_p = FFI::MemoryPointer.new(XZ::CHUNK_SIZE)
    bytes_before    = @lzma_stream[:total_in]

    @lzma_stream[:next_in] = input_buffer_p
    @lzma_stream[:avail_in] = input_buffer_p.size

    loop do
      @lzma_stream[:next_out]  = output_buffer_p
      @lzma_stream[:avail_out] = output_buffer_p.size

      # Compress the data
      res = XZ::LibLZMA.lzma_code(@lzma_stream.pointer, XZ::LibLZMA::LZMA_ACTION[:lzma_run])
      XZ::LZMAError.raise_if_necessary(res) # TODO: Warnings
      
      # Write the compressed data
      result = output_buffer_p.read_string(output_buffer_p.size - @lzma_stream[:avail_out])
      @delegate_io.write(result)

      # If the output buffer is completely filled, it's likely that there is
      # more data liblzma wants to hand to us. Start a new iteration,
      # but don't provide new input data.
      break unless @lzma_stream[:avail_out] == 0
    end

    # Return the number of bytes accepted by liblzma; this should
    # be equal to the size of +data+.
    bytes_after = @lzma_stream[:total_in]
    bytes_after - bytes_before
  rescue XZ::LZMAError => e
    raise(SystemCallError, e.message)
  end
  
end

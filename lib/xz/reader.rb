class XZ::StreamReader

  def initialize(io, memory_limit = XZ::LibLZMA::UINT64_MAX, flags = [:tell_unsupported_check], &block)
    @io = io
    @xz_stream = XZ::LZMAStream.new
    res = XZ::LibLZMA.lzma_stream_decoder(@xz_stream.pointer,
                                          memory_limit,
                                          flags.inject(0){|val, flag| val | XZ::LibLZMA.const_get(:"LZMA_#{flag.to_s.upcase}")})
    XZ::LZMAError.raise_if_necessary(res)
    
    if block_given?
      begin
        yield(self)
      ensure
        XZ::LibLZMA.lzma_end(@xz_stream.pointer)
      end
    end
   end

  def read(bytes = nil)
    if bytes
      input_buffer_p  = FFI::MemoryPointer.new(bytes)
      output_buffer_p = FFI::MemoryPointer.new(bytes)

      @xz_stream[:next_out] = output_buffer_p

      if @xz_stream[:avail_out] == 0
        if @io.eof?
          LibLZMA.lzma_code(@xz_stream.pointer, XZ::LibLZMA::LZMA_ACTION[:lzma_finish])
        else
          LibLZMA.lzma_code(@xz_stream.pointer, XZ::LibLZMA::LZMA_ACTION[:lzma_run])
        end
        
      @input = @io.read(XZ::CHUNK_SIZE)
      input_buffer_p.write_string(@input)
      
      @xz_stream[:next_in] = input_buffer_p
      @xz_stream[:avail_in] = XZ.send(:binary_size, @input)

      
      if @io.eof?
        LibLZMA.lzma_code(@xz_stream.pointer, XZ::LibLZMA::LZMA_ACTION[:lzma_finish])
      else
        LibLZMA.lzma_code(@xz_stream.pointer, XZ::LibLZMA::LZMA_ACTION[:lzma_run])
      end

      output_buffer_p.read_string(XZ::CHUNK_SIZE - stream[:avail_out])
    else

    end
  end

end

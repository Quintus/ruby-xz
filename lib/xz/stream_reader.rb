# -*- coding: utf-8 -*-

class XZ::StreamReader < XZ::Stream

  def initialize(delegate_io, memory_limit = XZ::LibLZMA::UINT64_MAX, flags = [:tell_unsupported_check])
    raise(ArgumentError, "Invalid memory limit set!") unless (0..XZ::LibLZMA::UINT64_MAX).include?(memory_limit)
    flags.each do |flag|
      raise(ArgumentError, "Unknown flag #{flag}!") unless [:tell_no_check, :tell_unsupported_check, :tell_any_check, :concatenated].include?(flag)
    end
    
    super(delegate_io)
    res = XZ::LibLZMA.lzma_stream_decoder(@lzma_stream,
                                          memory_limit,
                                          flags.inject(0){|val, flag| val | XZ::LibLZMA.const_get(:"LZMA_#{flag.to_s.upcase}")})
    XZ::LZMAError.raise_if_necessary(res)
  end
  
  private

  def unbuffered_read(length)
    raise(EOFError, "Input data completely processed!") if @lzma_finished
    
    input_buffer_p  = FFI::MemoryPointer.new(XZ::CHUNK_SIZE)
    output_buffer_p = FFI::MemoryPointer.new(length)

    @lzma_stream[:next_out]  = output_buffer_p
    @lzma_stream[:avail_out] = output_buffer_p.size

    loop do
      compressed_data = @delegate_io.read(XZ::CHUNK_SIZE) || ""
      input_buffer_p.write_string(compressed_data)
      
      @lzma_stream[:next_in]  = input_buffer_p
      @lzma_stream[:avail_in] = binary_size(compressed_data)

      res = XZ::LibLZMA.lzma_code(@lzma_stream.pointer, XZ::LibLZMA::LZMA_ACTION[:lzma_run])
      
      if res == XZ::LibLZMA::LZMA_RET[:lzma_buf_error]
        # When liblzma isn’t able to produce more output (-> output
        # buffer completely filled), it will signal LZMA_BUF_ERROR.
        # This means, we gathered the maximum possible data for this
        # call to #unbuffered_read. As it’s likely that liblzma wasn’t
        # able to process the whole input, we have to ensure that
        # the unprocessed input will be tried again in the next call
        # to #unbuffered_read by seeking back (note the minus sign below!)
        # to the position just behind the processed data.
        @delegate_io.seek(-@lzma_stream[:avail_in], IO::SEEK_CUR)
        #                 ↑ minus sign
        break
      elsif res == XZ::LibLZMA::LZMA_RET[:lzma_stream_end]
        # LZMA_STREAM_END is returned if a complete block has
        # been successfully decoded. Because this library doesn’t
        # support XZ-multi-block files, this means we’re finished here.
        @lzma_finished = true
        break
      else
        XZ::LZMAError.raise_if_necessary(res)
      end
    end

    output_buffer_p.read_string(@lzma_stream[:avail_out])
  rescue XZ::LZMAError => e
    raise(SystemCallError, e.message)
  end

end

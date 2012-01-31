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
    
    @input_buffer_p = FFI::MemoryPointer.new(XZ::CHUNK_SIZE)
  end
  
  def close
    super
    
    # Close the XZ stream
    res = XZ::LibLZMA.lzma_end(@lzma_stream.pointer)
    XZ::LZMAError.raise_if_necessary(res)

    # Return the number of bytes written in total.
    @lzma_stream[:total_out]
  end

  private

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

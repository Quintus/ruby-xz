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
    lzma_code(@delegate_io.read(XZ::CHUNK_SIZE), length)
  end

end

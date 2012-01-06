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
    lzma_code(data)
  end
  
end

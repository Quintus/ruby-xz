# -*- coding: utf-8 -*-

class XZ::Stream
  include IO::Like

  def initialize(delegate_io)
    @delegate_io    = delegate_io
    @lzma_stream    = XZ::LZMAStream.new
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

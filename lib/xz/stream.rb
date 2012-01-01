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
    @delegate_io = delegate_io
    @lzma_stream = XZ::LZMAStream.new
    @closed = false
  end

  def close
    super
    
    #1. Close the current file (an XZ stream may actually include
    #   multiple compressed files, which however is not supported by
    #   this library). For this we have to tell liblzma that
    #   the next bytes we pass to it are the last bytes (by means of
    #   the FINISH action). However, when this method is called all
    #   data is already compressed, so we just tell liblzma that
    #   there are exactly 0 bytes we want to compress before finishing
    #   the file.
    @lzma_stream[:next_in]  = nil # We can pass a NULL pointer here b/c liblzma only wants...
    @lzma_stream[:avail_in] = 0   #...to read 0 bytes from that pointer
    res = XZ::LibLZMA.lzma_code(@lzma_stream.pointer, XZ::LibLZMA::LZMA_ACTION[:lzma_finish])
    XZ::LZMAError.raise_if_necessary(res)

    #2. Close the whole XZ stream.
    res = XZ::LibLZMA.lzma_end(@lzma_stream.pointer)
    XZ::LZMAError.raise_if_necessary(res)

    #3. Return the number of bytes written in total.
    @lzma_stream[:total_out]
  end

  private

  #Delegates to XZ.lzma_code using the given IO and the internal
  #LZMAStream object. Returns the number of bytes written. All
  #LZMAError exception raised from XZ.lzma_code are automatically
  #converted to SystemCallError exceptions for the IO::Like module.
  def lzma_code(io)
    bytes_before = @lzma_stream[:total_out]
    
    # #lzma_code is a private method as it’s not supposed to be
    # used from outside this library. This method here however
    # actually _belongs_ to this library, hence there’s no harm
    # in using the private method.
    XZ.send(:lzma_code, io, @lzma_stream){|chunk| @delegate_io.write(chunk)}
    
    bytes_after = @lzma_stream[:total_out]
    
    bytes_after - bytes_before
  rescue XZ::LZMAError => e
    raise(SystemCallError, e.message)
  end

end

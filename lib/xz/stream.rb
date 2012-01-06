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
    @input_buffer_p = FFI::MemoryPointer.new(CHUNK_SIZE)
    @closed         = false
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

  #Executes lzma_code() exactly once and feeds it the given
  #string if possible, otherwise the string is cached for later. 
  #The second parameter indicates the number of bytes you want 
  #to receive, which by default is XZ::CHUNK_SIZE. This
  #method returns +chunk_size+ or less bytes as a BINARY-encoded
  #string.
  def lzma_code(str, chunk_size = XZ::CHUNK_SIZE)

    # It’s possible that there’s data left in the input stream.
    # Add our new data to the old input stream. As the result may
    # be bigger than the previous pointer size, we have to create
    # a new pointer with the appropriate size, i.e. old size + new size.
    # Then, we copy the unprocessed data over to the new pointer and add
    # the new data behind it. Caution: Heavy pointer operations!
    #
    # Note that + and - on FFI pointers returns a new FFI::Pointer
    # instance with its reference point and size changed accordingly.
    # Try in IRB with FFI::MemoryPointers to see how it works!
    #
    # :avail_in is the number of not yet processed bytes.
    #
    # TODO: It’s actually possible to get a NoMemoryError here if
    # the input grows and grows and grows, most likely during compression.
    # But this should only be an issue if you compress several gigabytes of
    # data at once, which is quite unlikely. Feel free to send a patch to
    # correct this problem! Also, note that the plain XZ.compress_stream method
    # doesn’t suffer from this problem.
    ptr = FFI::MemoryPointer.new(@lzma_steam[:avail_in] + binary_size(str))
    XZ::LibC.memcpy(@input_buffer_p + @lzma_stream[:avail_in], # The unprocessed data sits at the end of the pointer
                    ptr, 
                    @lzma_stream[:avail_in])
    new_start_ptr = ptr + @lzma_stream[:avail_in] # Seek behind the copied data
    new_start_ptr.write_string(str)               # Append new data
    
    # We can now discard the old input pointer as we’ve
    # constructed the new pointer with the new data.
    @input_buffer_p         = ptr
    @lzma_stream[:next_in]  = @input_buffer_p
    @lzma_stream[:avail_in] = @input_buffer_p.size
        
    # Provide a pointer to liblzma telling it where to store the
    # (de)compressed data.
    output_buffer_p    = FFI::MemoryPointer.new(chunk_size)
    stream[:next_out]  = output_buffer_p
    stream[:avail_out] = output_buffer_p.size

    # Tell liblzma to take action now
    res = XZ::LibLZMA.lzma_code(@lzma_stream.pointer,
                                XZ::LibLZMA::LZMA_ACTION[:lzma_run])

    XZ::LZMAError.raise_if_necessary(res)

    # At this point, liblzma may wants to provide more data to us
    # (most likely the case when you’re decompressing as the resulting
    # data is bigger than the original data). However, for this one
    # method call we’re asked to return a specific number of bytes,
    # therefore we have to postpone the reading of further bytes
    # from liblzma. When this method is called next time, we ask
    # liblzma for further data, which then not necessarily needs to
    # correspond with the new input we provide, i.e. the output may
    # actually belong to the input we provided last time.

    # Return the string of bytes we got from liblzma. Its length may
    # not necessarily be chunk_size as it’s likely to be less when
    # you’re compressing (as this is the sense of compression ;-)).
    # :avail_out is the number of *free* bytes free *behind*
    # the result data.
    result_bytes_num = chunk_size - @lzma_stream[:avail_out]
    output_buffer_p.read_string(result_bytes_num)
  rescue XZ::LZMAError => e
    raise(SystemCallError, e.message)
  end

end

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
      file   = File.open(io_or_filename.to_s) # Closed via method-ensure
      stream = new(file)
    end

    # If we got a block, ensure the Stream instance is closed after
    # the block has been left. Otherwise, behave the same way as ::new.
    if block_given?
      begin
        yield(stream)
      ensure
        stream.close unless stream.closed?
      end
    end
  ensure
    file.close if file
  end

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

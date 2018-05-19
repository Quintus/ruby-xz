# -*- coding: utf-8 -*-
#--
# (The MIT license)
#
# Basic liblzma-bindings for Ruby.
#
# Copyright © 2018 Marvin Gülker
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the ‘Software’),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the Software
# is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED ‘AS IS’, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#++

# The base class for XZ::StreamReader and XZ::StreamWriter.  This is
# an abstract class that is not meant to be used directly. You can,
# however, test against this class in <tt>kind_of?</tt> tests.
#
# XZ::StreamReader and XZ::StreamWriter are IO-like classes that allow
# you to access XZ-compressed data the same way you access an
# IO-object, easily allowing to fool other libraries that expect IO
# objects. The most noticable example for this may be reading and
# writing XZ-compressed tarballs using the archive-tar-minitar
# RubyGem; see XZ::StreamReader and XZ::StreamWriter for respective
# examples.
#
# Most of IO's methods are implemented in this class or one of the
# subclasses. The most notable exception is that it is not possible
# to seek in XZ archives (#seek and #pos= are not defined).
# Many methods that are not expressly documented in the RDoc
# still exist; this class uses Ruby's Forwardable module to forward
# them to the underlying IO object.
class XZ::Stream
  extend Forwardable

  def_delegator :@delegate_io, :"autoclose="
  def_delegator :@delegate_io, :"autoclose?"
  def_delegator :@delegate_io, :binmode
  def_delegator :@delegate_io, :"binmode?"
  def_delegator :@delegate_io, :"close_on_exec="
  def_delegator :@delegate_io, :"close_on_exec?"
  def_delegator :@delegate_io, :fcntl
  def_delegator :@delegate_io, :fdatasync
  def_delegator :@delegate_io, :fileno
  def_delegator :@delegate_io, :to_i
  def_delegator :@delegate_io, :flush # TODO: liblzma might have its own flush method that should be used
  def_delegator :@delegate_io, :fsync
  def_delegator :@delegate_io, :ioctl
  def_delegator :@delegate_io, :isatty
  def_delegator :@delegate_io, :pid
  #def_delegator :@delegate_io, :stat # If this is available the minitar gem thinks it's a File and wants to seek it O_o
  def_delegator :@delegate_io, :sync # TODO: use liblzma's own syncing functionality?
  def_delegator :@delegate_io, :"sync=" # TODO: use liblzma's own syncing functionality?
  def_delegator :@delegate_io, :"tty?"

  # Like IO#lineno and IO#lineno=.
  attr_accessor :lineno

  # Private API only for use by subclasses.
  def initialize(delegate_io) # :nodoc:
    @delegate_io = delegate_io
    @lzma_stream = XZ::LibLZMA::LZMAStream.malloc
    XZ::LibLZMA::LZMA_STREAM_INIT(@lzma_stream)

    @finished = false
    @lineno = 0
    @pos = 0
    @input_buffer_p  = Fiddle::Pointer.malloc(XZ::CHUNK_SIZE)
    @output_buffer_p = Fiddle::Pointer.malloc(XZ::CHUNK_SIZE)
  end

  # Pass the given +str+ into libzlma's lzma_code() function.
  # +action+ is either LibLZMA::LZMA_RUN (still working) or
  # LibLZMA::LZMA_FINISH (this is the last piece).
  def lzma_code(str, action) # :nodoc:
    previous_encoding = str.encoding
    str.force_encoding("BINARY") # Need to operate on bytes now

    begin
      pos = 0
      until pos > str.bytesize # Do not use >=, that conflicts with #lzma_finish
        substr = str[pos, XZ::CHUNK_SIZE]
        @input_buffer_p[0, str.bytesize] = substr
        pos += XZ::CHUNK_SIZE

        @lzma_stream.next_in  = @input_buffer_p
        @lzma_stream.avail_in = substr.bytesize

        loop do
          @lzma_stream.next_out  = @output_buffer_p
          @lzma_stream.avail_out = XZ::CHUNK_SIZE
          res = XZ::LibLZMA.lzma_code(@lzma_stream.to_ptr, action)
          XZ.send :check_lzma_code_retval, res # call package-private method

          data = @output_buffer_p[0, XZ::CHUNK_SIZE - @lzma_stream.avail_out]
          yield(data)

          break unless @lzma_stream.avail_out == 0
        end
      end
    ensure
      str.force_encoding(previous_encoding)
    end
  end

  # Partial implementation of +rewind+ abstracting common operations.
  # The subclasses implement the rest.
  def rewind # :nodoc:
    # Free the current lzma stream and rewind the underlying IO.
    # It is required to call #rewind before allocating a new lzma
    # stream, because if #rewind raises an exception (because the
    # underlying IO is not rewindable), a memory leak would occur
    # with regard to an allocated-but-never-freed lzma stream.
    finish
    @delegate_io.rewind

    # Reset internal state
    @pos = @lineno = 0
    @finished = false

    # Allocate a new lzma stream (subclasses will configure it).
    @lzma_stream = XZ::LibLZMA::LZMAStream.malloc
    XZ::LibLZMA::LZMA_STREAM_INIT(@lzma_stream)

    0 # Mimic IO#rewind's return value
  end

  # You can mostly treat this as if it were an IO object.
  # At least for subclasses. This class itself is abstract,
  # you shouldn't be using it directly at all.
  #
  # Returns the receiver.
  def to_io
    self
  end

  # Overridden in StreamReader to be like IO#eof?.
  # This abstract implementation only raises IOError.
  def eof?
    raise(IOError, "Stream not opened for reading")
  end

  # Alias for #eof?
  def eof
    eof?
  end

  # True if the delegate IO has been closed.
  def closed?
    @delegate_io.closed?
  end

  # True if liblzma's internal memory has been freed. For writer
  # instances, receiving true from this method also means that all
  # of liblzma's compressed data has been flushed to the underlying
  # IO object.
  def finished?
    @finished
  end

  # Free internal libzlma memory. This needs to be called before
  # you leave this object for the GC. If you used a block-form
  # initializer, this done automatically for you.
  #
  # Subsequent calls to #read or #write will cause an IOError.
  #
  # Returns the underlying IO object. This allows you to retrieve
  # the File instance that was automatically created when using
  # the +open+ method's block form.
  def finish
    return if @finished

    # Clean up the lzma_stream structure's internal memory.
    # This would belong into a destructor if Ruby had that.
    XZ::LibLZMA.lzma_end(@lzma_stream)
    @finished = true

    @delegate_io
  end


  # If not done yet, call #finish. Then close the delegate IO.
  # The latter action is going to cause the delegate IO to
  # flush its buffer. After this method returns, it is guaranteed
  # that all pending data has been flushed to the OS' kernel.
  def close
    finish unless @finished
    @delegate_io.close unless @delegate_io.closed?
    nil
  end

  # Always raises IOError, because XZ streams can never be duplex.
  def close_read
    raise(IOError, "Not a duplex I/O stream")
  end

  # Always raises IOError, because XZ streams can never be duplex.
  def close_write
    raise(IOError, "Not a duplex I/O stream")
  end

  # Overridden in StreamReader to be like IO#read.
  # This abstract implementation only raises IOError.
  def read(*args)
    raise(IOError, "Stream not opened for reading")
  end

  # Overridden in StreamWriter to be like IO#write.
  # This abstract implementation only raises IOError.
  def write(*args)
    raise(IOError, "Stream not opened for writing")
  end

  # Returns the position in the *decompressed* data (regardless of
  # whether this is a reader or a writer instance).
  def pos
    @pos
  end
  alias tell pos

  # Do not define #pos= and #seek, not even to throw NotImplementedError.
  # Reason: The minitar gem thinks it can use this methods then and provokes
  # the NotImplementedError exception.

  # Like IO#<<.
  def <<(obj)
    write(obj.to_s)
  end

  # Like IO#advise. No-op, because not meaningful on compressed data.
  def advise
    nil
  end

  # Like IO#getbyte. Note this method isn't exactly performant,
  # because it actually reads compressed data as a string and then
  # needs to figure out the bytes from that again.
  def getbyte
    return nil if eof?
    read(1).bytes.first
  end

  # Like IO#readbyte.
  def readbyte
    getbyte || raise(EOFError, "End of stream reached")
  end

  # libzlma doesn't provide charset information on the data stored
  # in compressed format, hence character boundaries cannot usefully
  # be guessed. If your compressed data contains non-ascii characters,
  # this method will return partially encoded sequences. Consequently,
  # you should not use this method when dealing with non-ascii compressed
  # data. Other than that, it acts like IO#getc.
  def getc
    read(1)
  end

  # Like IO#readchar.
  def readchar
    getc || raise(EOFError, "End of stream reached")
  end

  # Like IO#gets.
  def gets(separator = $/, limit = nil)
    return nil if eof?
    @lineno += 1

    # Mirror IO#gets' weird call-seq
    if separator.respond_to?(:to_int)
      limit = separator.to_int
      separator = $/
    end

    buf = ""
    until eof? || (limit && buf.bytesize >= limit)
      buf << read(1)
      return buf if buf[-1] == separator
    end

    buf
  end

  # Like IO#readline.
  def readline(*args)
    gets(*args) || raise(EOFError, "End of stream reached")
  end

  # Like IO#each.
  def each(*args)
    return enum_for __method__ unless block_given?

    while line = gets(*args)
      yield(line)
    end
  end
  alias each_line each

  # Like IO#each_byte.
  def each_byte
    return enum_for __method__ unless block_given?

    while byte = getbyte
      yield(byte)
    end
  end

  # Like IO#each_char.
  def each_char
    return enum_for __method__ unless block_given?

    while char = getc
      yield(char)
    end
  end

  # This method is specifically meant for multibyte data.
  # Since there's no way to know if the compressed data
  # is multibyte, calling this method causes a
  # NotImplementedError exception.
  def each_codepoint
    raise(NotImplementedError, "Since libzlma does not provide charset information, each_codepoint can't be implemented.")
  end

  # Like IO#printf.
  def printf(*args)
    write(sprintf(*args))
    nil
  end

  # Like IO#putc.
  def putc(obj)
    if obj.respond_to? :chr
      write(obj.chr)
    elsif obj.respond_to? :to_str
      write(obj.to_str)
    else
      raise(TypeError, "Can only #putc strings and numbers")
    end
  end

  def puts(*objs)
    if objs.empty?
      write("\n")
      return nil
    end

    objs.each do |obj|
      if obj.respond_to? :to_ary
        puts(*obj.to_ary)
      else
        # Don't squeeze multiple subsequent trailing newlines in `obj'
        if obj.end_with?("\n")
          write(obj)
        else
          write(obj.to_s + "\n")
        end
      end
    end
    nil
  end

  # Like IO#print.
  def print(*objs)
    if objs.empty?
      write($_)
    else
      objs.each do |obj|
        write(obj.to_s)
        write($,) if $,
      end
    end

    write($\) if $\
    nil
  end

  # It is not possible to reopen an lzma stream, hence this
  # method always raises NotImplementedError.
  def reopen(*args)
    raise(NotImplementedError, "Can't reopen an lzma stream")
  end

end

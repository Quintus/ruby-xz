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

# An IO-like writer class for XZ-compressed data, allowing you to
# write uncompressed data to a stream which ends up as compressed data
# in a wrapped stream such as a file.
#
# A StreamWriter object actually wraps another IO object it writes the
# XZ-compressed data to. Here’s an ASCII art image to demonstrate way
# data flows when using StreamWriter to write to a compressed file:
#
#           +-----------------+  +------------+
#   YOUR  =>|StreamWriter's   |=>|Wrapped IO's|=> ACTUAL
#   DATA  =>|(liblzma) buffers|=>|buffers     |=>  FILE
#           +-----------------+  +------------+
#
# This graphic also illustrates why it is unlikely to see written data
# directly appear in the file on your harddisk; the data is cached at
# least twice before it actually gets written out. Regarding file
# closing that means that before you can be sure any pending data has
# been written to the file you have to close both the StreamWriter
# instance and then the wrapped IO object (in *exactly* that order,
# otherwise data loss and unexpected exceptions may occur!).
#
# Calling the #close method closes both the XZ writer and the
# underlying IO object in the correct order. This is akin to the
# behaviour exposed by Ruby's own Zlib::GzipWriter class. If you
# expressly don't want to close the underlying IO instance, you need
# to manually call StreamWriter#finish and never call
# StreamWriter#close. Instead, you then close your IO object manually
# using IO#close once you're done with it.
#
# *NOTE*: Using #finish inside the +open+ method's block allows
# you to continue using that writer's File instance as it is
# returned by #finish.
#
# == Example
#
# Together with the <tt>archive-tar-minitar</tt> gem, this library
# can be used to create XZ-compressed TAR archives (these commonly
# use a file extension of <tt>.tar.xz</tt> or rarely <tt>.txz</tt>).
#
#   XZ::StreamWriter.open("foo.tar.xz") do |txz|
#     # This automatically closes txz
#     Archive::Tar::Minitar.pack("foo", txz)
#   end
class XZ::StreamWriter < XZ::Stream

  attr_reader :level
  attr_reader :options

  def self.open(filename, compression_level = 6, options = {})
    file = File.open(filename, "wb")
    writer = new(file, compression_level, options)

    if block_given?
      begin
        yield(writer)
      ensure
        # Close both writer and delegate IO via writer.close
        # unless the writer has manually been finished (usually
        # not closing the delegate IO then).
        writer.close unless writer.finished?
      end
    end

    writer
  end

  def initialize(delegate_io, compression_level = 6, options = {})
    super(delegate_io)
    options[:check]   ||= :crc64
    options[:extreme] ||= false

    @level    = compression_level
    @options  = options.freeze

    res = XZ::LibLZMA.lzma_easy_encoder(@lzma_stream.to_ptr,
                                    @level,
                                    XZ::LibLZMA.const_get(:"LZMA_CHECK_#{options[:check].upcase}"))
    XZ::LZMAError.raise_if_necessary(res)
  end

  # Mostly like IO#write. Additionally it raises an IOError
  # if #finish has been called previously.
  def write(*args)
    raise(IOError, "Cannot write to a finished liblzma stream") if @finished

    origpos = @pos

    args.each do |arg|
      @pos += arg.to_s.bytesize
      lzma_code(arg.to_s, XZ::LibLZMA::LZMA_RUN) do |compressed|
        @delegate_io.write(compressed)
      end
    end

    @pos - origpos # Return number of bytes consumed from input
  end

  # Like superclass' method, but also ensures liblzma flushes all
  # compressed data to the delegate IO.
  def finish
    lzma_code("", XZ::LibLZMA::LZMA_FINISH) { |compressed| @delegate_io.write(compressed) }
    super
  end

  # Abort the current compression process and reset everything
  # to the start. Writing into this writer will cause existing data
  # on the underlying IO to be overwritten after this method has been
  # called.
  #
  # The delegte IO has to support the #rewind method. Otherwise like
  # IO#rewind.
  def rewind
    super

    res = XZ::LibLZMA.lzma_easy_encoder(@lzma_stream.to_ptr,
                                    @level,
                                    XZ::LibLZMA.const_get(:"LZMA_CHECK_#{options[:check].upcase}"))
    XZ::LZMAError.raise_if_necessary(res)

    0 # Mimic IO#rewind's return value
  end

  def external_encoding
    nil
  end

  def internal_encoding
    nil
  end

  # Human-readable description
  def inspect
    "<#{self.class} pos=#{@pos} finished=#{@finished} closed=#{closed?} io=#{@delegate_io.inspect}>"
  end

end

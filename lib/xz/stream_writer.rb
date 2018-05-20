# -*- coding: utf-8 -*-
#--
# Basic liblzma-bindings for Ruby.
#
# Copyright © 2011-2018 Marvin Gülker et al.
#
# See AUTHORS for the full list of contributors.
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
class XZ::StreamWriter < XZ::Stream

  # Compression level used for this writer (set on instanciation).
  attr_reader :level
  # Checksum algorithm in use.
  attr_reader :check

  # call-seq:
  #   open(filename [, compression_level = 6 [, options ]]) → stream_writer
  #   open(filename [, compression_level = 6 [, options ]]){|sw| ...} → stream_writer
  #
  # Creates a new instance for writing to a compressed file. The File
  # instance is opened internally and then wrapped via ::new. The
  # block form automatically closes both the liblzma stream and the
  # internal File instance in the correct order. The non-block form
  # does neither, leaving it to you to call #finish or #close later.
  #
  # === Parameters
  # [filename]
  #   The file to open.
  # [sw (block argument)]
  #   The created StreamWriter instance.
  #
  # See ::new for the other parameters.
  #
  # === Return value
  # Returns the newly created instance.
  #
  # === Remarks
  # Starting with version 1.0.0, the block form also returns the newly
  # created instance rather than the block's return value. This is
  # in line with Ruby's own GzipWriter.open API.
  #
  # === Example
  #     # Normal usage
  #     XZ::StreamWriter.open("myfile.txt.xz") do |xz|
  #       xz.puts "Compress this line"
  #       xz.puts "And this line as well"
  #     end
  #
  #     # If for whatever reason you want to do something else with
  #     # the internally opened file:
  #     file = nil
  #     XZ::StreamWriter.open("myfile.txt.xz") do |xz|
  #       xz.puts "Compress this line"
  #       xz.puts "And this line as well"
  #       file = xz.finish
  #     end
  #     # At this point, the liblzma stream has been closed, but `file'
  #     # now contains the internally created File instance, which is
  #     # still open. Don't forget to close it yourself at some point
  #     # to flush it.
  #     file.close
  #
  #     # Or just don't use the block form:
  #     xz = StreamWriter.open("myfile.txt.xz")
  #     xz.puts "Compress this line"
  #     xz.puts "And this line as well"
  #     file = xz.finish
  #     file.close # Don't forget to close it manually (or use xz.close instead of xz.finish above)
  def self.open(filename, **args)
    file = File.open(filename, "wb")
    writer = new(file, **args)

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

  # Creates a new instance that is wrapped around the given IO instance.
  #
  # === Parameters
  # ==== Positional parameters
  # [delegate_io]
  #   The IO instance to wrap. It has to be opened in binary mode,
  #   otherwise the data it writes to the hard disk will be corrupt.
  #
  # ==== Keyword arguments
  # [compression_level (6)]
  #   Compression strength. Higher values indicate a
  #   smaller result, but longer compression time. Maximum
  #   is 9.
  # [:check (:crc64)]
  #   The checksum algorithm to use for verifying
  #   the data inside the archive. Possible values are:
  #   * :none
  #   * :crc32
  #   * :crc64
  #   * :sha256
  # [:extreme (false)]
  #   Tries to get the last bit out of the
  #   compression. This may succeed, but you can end
  #   up with *very* long computation times.
  # [:external_encoding (Encoding.default_external)]
  #   Transcode to this encoding when writing. Defaults
  #   to Encoding.default_external, which by default is
  #   set from the environment.
  #
  # === Return value
  # Returns the newly created instance.
  #
  # === Remarks
  # This method does not close the underlying IO nor does it automatically
  # flush libzlma. You'll need to do that manually using #close or #finish.
  # See ::open for a method that supports a block with auto-closing.
  #
  # This method used to accept a block in earlier versions. This
  # behaviour has been removed in version 1.0.0 to synchronise the API
  # with Ruby's own GzipWriter.new.
  #
  # === Example
  #     # Normal usage:
  #     file = File.open("myfile.txt.xz", "wb") # Note binary mode
  #     xz = XZ::StreamWriter.new(file)
  #     xz.puts("Compress this line")
  #     xz.puts("And this second line")
  #     xz.close # Closes both the libzlma stream and `file'
  #
  #     # Expressly closing the delegate IO manually:
  #     File.open("myfile.txt.xz", "wb") do |file| # Note binary mode
  #       xz = XZ::StreamWriter.new(file)
  #       xz.puts("Compress this line")
  #       xz.puts("And this second line")
  #       xz.finish # Flushes libzlma, but keeps `file' open.
  #     end # Here, `file' is closed.
  def initialize(delegate_io, level: 6, check: :crc64, extreme: false, external_encoding: nil)
    super(delegate_io)

    raise(ArgumentError, "Invalid compression level!")  unless (0..9).include?(level)
    raise(ArgumentError, "Invalid checksum specified!") unless [:none, :crc32, :crc64, :sha256].include?(check)

    set_encoding(external_encoding) if external_encoding

    @check  = check
    @level  = level
    @level |= LibLZMA::LZMA_PRESET_EXTREME if extreme

    res = XZ::LibLZMA.lzma_easy_encoder(@lzma_stream.to_ptr,
                                    @level,
                                    XZ::LibLZMA.const_get(:"LZMA_CHECK_#{@check.upcase}"))
    XZ::LZMAError.raise_if_necessary(res)
  end

  # Mostly like IO#write. Additionally it raises an IOError
  # if #finish has been called previously.
  def write(*args)
    raise(IOError, "Cannot write to a finished liblzma stream") if @finished

    origpos = @pos

    args.each do |arg|
      @pos += arg.to_s.bytesize

      # Apply external encoding if requested
      if @external_encoding && @external_encoding != Encoding::BINARY
        arg = arg.to_s.encode(@external_encoding)
      end

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
                                    XZ::LibLZMA.const_get(:"LZMA_CHECK_#{@check.upcase}"))
    XZ::LZMAError.raise_if_necessary(res)

    0 # Mimic IO#rewind's return value
  end

  # Human-readable description
  def inspect
    "<#{self.class} pos=#{@pos} finished=#{@finished} closed=#{closed?} io=#{@delegate_io.inspect}>"
  end

end

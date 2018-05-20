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

require "pathname"
require "fiddle"
require "fiddle/import"
require "stringio"
require "forwardable"

# The namespace and main module of this library. Each method of this
# module may raise exceptions of class XZ::LZMAError, which is not
# named in the methods' documentations anymore.
module XZ

  # Number of bytes read in one chunk.
  CHUNK_SIZE = 4096

  class << self

    # Force ruby-xz to be silent about deprecations. Using this is
    # discouraged so that you are aware of upcoming changes to the
    # API. However, if your standard error stream is closed,
    # outputting the deprecation notices might result in an exception,
    # so this method allows you to surpress these notices. Ensure you
    # read the HISTORY.rdoc file carefully instead.
    def disable_deprecation_notices=(bool)
      @disable_deprecation_notices = bool
    end

    # Output a deprecation notice.
    def deprecate(msg) # :nodoc:
      @disable_deprecation_notices ||= false

      unless @disable_deprecation_notices
        $stderr.puts("DEPRECATION NOTICE: #{msg}\n#{caller.drop(1).join("\n\t")}")
      end
    end

    # call-seq:
    #   decompress_stream(io [, kw ] )                 → a_string
    #   decompress_stream(io [, kw ] ] ){|chunk| ... } → an_integer
    #   decode_stream(io [, kw ] ] )                   → a_string
    #   decode_stream(io [, kw ] ){|chunk| ... }       → an_integer
    #
    # Decompresses a stream containing XZ-compressed data.
    #
    # === Parameters
    # ==== Positional parameters
    #
    # [io]
    #   The IO to read from. It must be opened for reading in
    #   binary mode.
    # [chunk (Block argument)]
    #   One piece of decompressed data. See Remarks section below
    #   for information about its encoding.
    #
    # ==== Keyword arguments
    #
    # [memory_limit (+UINT64_MAX+)]
    #   If not XZ::LibLZMA::UINT64_MAX, makes liblzma
    #   use no more memory than +memory_limit+ bytes.
    #
    # [flags (<tt>[:tell_unsupported_check]</tt>)]
    #   Additional flags
    #   passed to liblzma (an array). Possible flags are:
    #
    #   [:tell_no_check]
    #     Spit out a warning if the archive hasn't an
    #     integrity checksum.
    #   [:tell_unsupported_check]
    #     Spit out a warning if the archive
    #     has an unsupported checksum type.
    #   [:concatenated]
    #     Decompress concatenated archives.
    # [external_encoding (Encoding.default_external)]
    #   Assume the decompressed data inside the compressed data
    #   has this encoding. See Remarks section.
    # [internal_encoding (Encoding.default_internal)]
    #   Request transcoding of the decompressed data into this
    #   encoding if not nil. Note that Encoding.default_internal
    #   is nil by default. See Remarks section.
    #
    # === Return value
    #
    # If a block was given, returns the number of bytes
    # written. Otherwise, returns the decompressed data as a
    # BINARY-encoded string.
    #
    # === Raises
    #
    # [Encoding::InvalidByteSequenceError]
    #   1. You requested an “internal encoding” conversion
    #      and the archive contains invalid byte sequences
    #      in the external encoding.
    #   2. You requested an “internal encoding” conversion, used
    #      the block form of this method, and liblzma decided
    #      to cut the decompressed data into chunks in mid of
    #      a multibyte character. See Remarks section for an
    #      explanation.
    #
    # === Example
    #
    #   data = File.open("archive.xz", "rb"){|f| f.read}
    #   io = StringIO.new(data)
    #
    #   XZ.decompress_stream(io) #=> "I AM THE DATA"
    #   io.rewind
    #
    #   str = ""
    #   XZ.decompress_stream(io, XZ::LibLZMA::UINT64_MAX, [:tell_no_check]){|c| str << c} #=> 13
    #   str #=> "I AM THE DATA"
    #
    # === Remarks
    #
    # The block form is *much* better on memory usage, because it
    # doesn't have to load everything into RAM at once. If you don't
    # know how big your data gets or if you want to decompress much
    # data, use the block form. Of course you shouldn't store the data
    # you read in RAM then as in the example above.
    #
    # This method honours Ruby's external and internal encoding concept.
    # All documentation about this applies to this method, with the
    # exception that the external encoding does not refer to the data
    # on the hard disk (that's compressed XZ data, it's always binary),
    # but to the data inside the XZ container, i.e. to the *decompressed*
    # data. Any strings you receive from this method (regardless of
    # whether via return value or via the +chunk+ block argument) will
    # first be tagged with the external encoding. If you set an internal
    # encoding (either via the +internal_encoding+ parameter or via
    # Ruby's default internal encoding) that string will be transcoded
    # from the external encoding to the internal encoding before you
    # even see it; in that case, the return value or chunk block argument
    # will be encoded in the internal encoding. Internal encoding is
    # disabled in Ruby by default and the argument for this method also
    # defaults to nil.
    #
    # Due to the external encoding being applied, it can happen that
    # +chunk+ contains an incomplete multibyte character causing
    # <tt>valid_encoding?</tt> to return false if called on +chunk+,
    # because liblzma doesn't know about encodings. The rest of the
    # character will be yielded to the block in the next iteration
    # then as liblzma progresses with the decompression from the XZ
    # format. In other words, be prepared that +chunk+ can contain
    # incomplete multibyte chars.
    #
    # This can have nasty side effects if you requested an internal
    # encoding automatic transcoding and used the block form. Since
    # this method applies the internal encoding transcoding before the
    # chunk is yielded to the block, String#encode gets the incomplete
    # multibyte character. In that case, you will receive an
    # Encoding::InvalidByteSequenceError exception even though your
    # data is perfectly well-formed inside the XZ data. It's just
    # that liblzma during decompression cut the chunks at an
    # unfortunate place. To avoid this, do not request internal encoding
    # conversion when using the block form, but instead transcode
    # the data manually after you have decompressed the entire data.
    def decompress_stream(io, memory_limit: LibLZMA::UINT64_MAX, flags: [:tell_unsupported_check], external_encoding: nil, internal_encoding: nil, &block)
      raise(ArgumentError, "Invalid memory limit set!") unless memory_limit > 0 && memory_limit <= LibLZMA::UINT64_MAX
      raise(ArgumentError, "external_encoding must be set if internal_encoding transcoding is requested") if internal_encoding && !external_encoding

      # The ArgumentError above is only about the concrete arguments
      # (to sync with Ruby's IO API), not about the implied internal
      # encoding, which might still kick in (and does, see below).
      external_encoding ||= Encoding.default_external
      internal_encoding ||= Encoding.default_internal

      # bit-or all flags
      allflags = flags.inject(0) do |val, flag|
        flag = LibLZMA::LZMA_DECODE_FLAGS[flag] || raise(ArgumentError, "Unknown flag #{flag}!")
        val | flag
      end

      stream = LibLZMA::LZMAStream.malloc
      LibLZMA.LZMA_STREAM_INIT(stream)
      res = LibLZMA.lzma_stream_decoder(stream.to_ptr,
                                        memory_limit,
                                        allflags)

      LZMAError.raise_if_necessary(res)

      res = ""
      res.encode!(Encoding::BINARY)
      if block_given?
        res = lzma_code(io, stream) do |chunk|
          chunk = chunk.dup # Do not write somewhere into the fiddle pointer while encoding (-> can segfault)
          chunk.force_encoding(external_encoding) if external_encoding
          chunk.encode!(internal_encoding)        if internal_encoding
          yield(chunk)
        end
      else
        lzma_code(io, stream){|chunk| res << chunk}
        res.force_encoding(external_encoding) if external_encoding
        res.encode!(internal_encoding)        if internal_encoding
      end

      LibLZMA.lzma_end(stream.to_ptr)

      block_given? ? stream.total_out : res
    end
    alias decode_stream decompress_stream

    # call-seq:
    #   compress_stream(io [, kw ] ) → a_string
    #   compress_stream(io [, kw ] ){|chunk| ... } → an_integer
    #   encode_stream(io [, kw ] ) → a_string
    #   encode_stream(io [, kw ] ){|chunk| ... } → an_integer
    #
    # Compresses a stream of data into XZ-compressed data.
    #
    # === Parameters
    # ==== Positional arguments
    #
    # [io]
    #   The IO to read the data from. Must be opened for
    #   reading.
    # [chunk (Block argument)]
    #   One piece of compressed data. This is always tagged
    #   as a BINARY string, since it's compressed binary data.
    #
    # ==== Keyword arguments
    # All keyword arguments are optional.
    #
    # [level (6)]
    #   Compression strength. Higher values indicate a
    #   smaller result, but longer compression time. Maximum
    #   is 9.
    #
    # [check (:crc64)]
    #   The checksum algorithm to use for verifying
    #   the data inside the archive. Possible values are:
    #   * :none
    #   * :crc32
    #   * :crc64
    #   * :sha256
    #
    # [extreme (false)]
    #   Tries to get the last bit out of the
    #   compression. This may succeed, but you can end
    #   up with *very* long computation times.
    #
    # === Return value
    #
    # If a block was given, returns the number of bytes
    # written. Otherwise, returns the compressed data as a
    # BINARY-encoded string.
    #
    # === Example
    #   data = File.read("file.txt")
    #   i = StringIO.new(data)
    #   XZ.compress_stream(i) #=> Some binary blob
    #
    #   i.rewind
    #   str = ""
    #
    #   XZ.compress_stream(i, level: 4, check: :sha256) do |c|
    #     str << c
    #   end #=> 123
    #   str #=> Some binary blob
    #
    # === Remarks
    #
    # The block form is *much* better on memory usage, because it
    # doesn't have to load everything into RAM at once. If you don't
    # know how big your data gets or if you want to compress much
    # data, use the block form. Of course you shouldn't store the data
    # your read in RAM then as in the example above.
    #
    # For the +io+ object passed Ruby's normal external and internal
    # encoding rules apply while it is read from by this method. These
    # encodings are not changed on +io+ by this method. The data you
    # receive in the block (+chunk+) above is binary data (compressed
    # data) and as such encoded as BINARY.
    def compress_stream(io, level: 6, check: :crc64, extreme: false, &block)
      raise(ArgumentError, "Invalid compression level!") unless (0..9).include?(level)
      raise(ArgumentError, "Invalid checksum specified!") unless [:none, :crc32, :crc64, :sha256].include?(check)

      level |= LibLZMA::LZMA_PRESET_EXTREME if extreme

      stream = LibLZMA::LZMAStream.malloc
      LibLZMA::LZMA_STREAM_INIT(stream)
      res = LibLZMA.lzma_easy_encoder(stream.to_ptr,
                                      level,
                                      LibLZMA.const_get(:"LZMA_CHECK_#{check.upcase}"))

      LZMAError.raise_if_necessary(res)

      res = ""
      res.encode!(Encoding::BINARY)
      if block_given?
        res = lzma_code(io, stream, &block)
      else
        lzma_code(io, stream){|chunk| res << chunk}
      end

      LibLZMA.lzma_end(stream.to_ptr)

      block_given? ? stream.total_out : res
    end
    alias encode_stream compress_stream

    # Compresses +in_file+ and writes the result to +out_file+.
    #
    # === Parameters
    #
    # [in_file]
    #   The path to the file to read from.
    # [out_file]
    #   The path of the file to write to. If it exists, it will be
    #   overwritten.
    #
    # For the keyword parameters, see the ::compress_stream method.
    #
    # === Return value
    #
    # The number of bytes written, i.e. the size of the archive.
    #
    # === Example
    #
    #   XZ.compress_file("myfile.txt", "myfile.txt.xz")
    #   XZ.compress_file("myarchive.tar", "myarchive.tar.xz")
    #
    # === Remarks
    #
    # This method is safe to use with big files, because files are not
    # loaded into memory completely at once.
    def compress_file(in_file, out_file, **args)
      File.open(in_file, "rb") do |i_file|
        File.open(out_file, "wb") do |o_file|
          compress_stream(i_file, **args) do |chunk|
            o_file.write(chunk)
          end
        end
      end
    end

    # Compresses arbitrary data using the XZ algorithm.
    #
    # === Parameters
    #
    # [str] The data to compress.
    #
    # For the keyword parameters, see the #compress_stream method.
    #
    # === Return value
    #
    # The compressed data as a BINARY-encoded string.
    #
    # === Example
    #
    #   data = "I love Ruby"
    #   comp = XZ.compress(data) #=> binary blob
    #
    # === Remarks
    #
    # Don't use this method for big amounts of data--you may run out
    # of memory. Use compress_file or compress_stream instead.
    def compress(str, **args)
      s = StringIO.new(str)
      compress_stream(s, **args)
    end

    # Decompresses data in XZ format.
    #
    # === Parameters
    #
    # [str] The data to decompress.
    #
    # For the keyword parameters, see the decompress_stream method.
    #
    # === Return value
    #
    # The decompressed data as a BINARY-encoded string.
    #
    # === Example
    #
    #   comp = File.open("data.xz", "rb"){|f| f.read}
    #   data = XZ.decompress(comp) #=> "I love Ruby"
    #
    # === Remarks
    #
    # Don't use this method for big amounts of data--you may run out
    # of memory. Use decompress_file or decompress_stream instead.
    #
    # Read #decompress_stream's Remarks section for notes on the
    # return value's encoding.
    def decompress(str, **args)
      s = StringIO.new(str)
      decompress_stream(s, **args)
    end

    # Decompresses +in_file+ and writes the result to +out_file+.
    #
    # ===Parameters
    #
    # [in_file]
    #   The path to the file to read from.
    # [out_file]
    #   The path of the file to write to. If it exists, it will
    #   be overwritten.
    #
    # For the keyword parameters, see the decompress_stream method.
    #
    # === Return value
    #
    # The number of bytes written, i.e. the size of the uncompressed
    # data.
    #
    # === Example
    #
    #   XZ.decompress_file("myfile.txt.xz", "myfile.txt")
    #   XZ.decompress_file("myarchive.tar.xz", "myarchive.tar")
    #
    # === Remarks
    #
    # This method is safe to use with big files, because files are not
    # loaded into memory completely at once.
    def decompress_file(in_file, out_file, **args)
      File.open(in_file, "rb") do |i_file|
        File.open(out_file, "wb") do |o_file|
          decompress_stream(i_file, internal_encoding: nil, external_encoding: Encoding::BINARY, **args) do |chunk|
            o_file.write(chunk)
          end
        end
      end
    end

    private

    # This method does the heavy work of (de-)compressing a stream. It
    # takes an IO object to read data from (that means the IO must be
    # opened for reading) and a XZ::LibLZMA::LZMAStream object that is used to
    # (de-)compress the data. Furthermore this method takes a block
    # which gets passed the (de-)compressed data in chunks one at a
    # time--this is needed to allow (de-)compressing of very large
    # files that can't be loaded fully into memory.
    def lzma_code(io, stream)
      input_buffer_p  = Fiddle::Pointer.malloc(CHUNK_SIZE) # automatically freed by fiddle on GC
      output_buffer_p = Fiddle::Pointer.malloc(CHUNK_SIZE) # automatically freed by fiddle on GC

      while str = io.read(CHUNK_SIZE)
        input_buffer_p[0, str.bytesize] = str

        # Set the data for compressing
        stream.next_in  = input_buffer_p
        stream.avail_in = str.bytesize

        # Now loop until we gathered all the data in
        # stream[:next_out]. Depending on the amount of data, this may
        # not fit into the buffer, meaning that we have to provide a
        # pointer to a "new" buffer that liblzma can write into. Since
        # liblzma already set stream[:avail_in] to 0 in the first
        # iteration, the extra call to the lzma_code() function
        # doesn't hurt (indeed the pipe_comp example from liblzma
        # handles it this way too). Sometimes it happens that the
        # compressed data is bigger than the original (notably when
        # the amount of data to compress is small).
        loop do
          # Prepare for getting the compressed_data
          stream.next_out  = output_buffer_p
          stream.avail_out = CHUNK_SIZE

          # Compress the data
          res = if io.eof?
            LibLZMA.lzma_code(stream.to_ptr, LibLZMA::LZMA_FINISH)
          else
            LibLZMA.lzma_code(stream.to_ptr, LibLZMA::LZMA_RUN)
          end
          check_lzma_code_retval(res)

          # Write the compressed data
          # Note: avail_out gives how much space is left after the new data
          data = output_buffer_p[0, CHUNK_SIZE - stream.avail_out]
          yield(data)

          # If the buffer is completely filled, it's likely that there
          # is more data liblzma wants to hand to us. Start a new
          # iteration, but don't provide new input data.
          break unless stream.avail_out == 0
        end #loop
      end #while
    end #lzma_code

    # Checks for errors and warnings that can be derived from the
    # return value of the lzma_code() function and shows them if
    # necessary.
    def check_lzma_code_retval(code)
      case code
      when LibLZMA::LZMA_NO_CHECK then warn("Couldn't verify archive integrity--archive has no integrity checksum.")
      when LibLZMA::LZMA_UNSUPPORTED_CHECK then warn("Couldn't verify archive integrity--archive has an unsupported integrity checksum.")
      when LibLZMA::LZMA_GET_CHECK then nil # This isn't useful. It indicates that the checksum type is now known.
      else
        LZMAError.raise_if_necessary(code)
      end
    end

  end #class << self

end

require_relative "xz/version"
require_relative "xz/fiddle_helper"
require_relative "xz/lib_lzma"
require_relative "xz/stream"
require_relative "xz/stream_writer"
require_relative "xz/stream_reader"

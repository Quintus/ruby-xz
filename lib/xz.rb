#Encoding: UTF-8
=begin (The MIT License)

Basic liblzma-bindings for Ruby.

Copyright © 2011 Marvin Gülker

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the ‘Software’),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the Software
is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED ‘AS IS’, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
=end

require "ffi"
require 'stringio'

#The namespace and main module of this library. Each method of this module
#may raise exceptions of class XZ::LZMAError, which is not named in the
#methods' documentations anymore.
module XZ
  
  #This module wraps functions and enums used by liblzma.
  module LibLZMA
    extend FFI::Library
    
    #The maximum value of an uint64_t, as defined by liblzma.
    #Should be the same as
    #  (2 ** 64) - 1
    UINT64_MAX = 18446744073709551615
    
    #Activates extreme compression. Same as xz's "-e" commandline switch.
    LZMA_PRESET_EXTREME = 1 << 31
    
    LZMA_TELL_NO_CHECK = 0x02
    LZMA_TELL_UNSUPPORTED_CHECK = 0x02
    LZMA_TELL_ANY_CHECK = 0x04
    LZMA_CONCATENATED = 0x08
    
    #Placeholder enum used by liblzma for later additions.
    LZMA_RESERVED_ENUM = enum :lzma_reserved_enum, 0
    
    #Actions that can be passed to the lzma_code() function.
    LZMA_ACTION = enum  :lzma_run, 0,
                        :lzma_sync_flush,
                        :lzma_full_flush,
                        :lzma_finish
                        
    #Integrity check algorithms supported by liblzma.
    LZMA_CHECK = enum :lzma_check_none, 0,
                      :lzma_check_crc32, 1,
                      :lzma_check_crc64, 4,
                      :lzma_check_sha256, 10
                      
    #Possible return values of liblzma functions.
    LZMA_RET = enum :lzma_ok, 0,
                    :lzma_stream_end,
                    :lzma_no_check,
                    :lzma_unsupported_check,
                    :lzma_get_check,
                    :lzma_mem_error,
                    :lzma_memlimit_error,
                    :lzma_format_error,
                    :lzma_options_error,
                    :lzma_data_error,
                    :lzma_buf_error,
                    :lzma_prog_error
    
    ffi_lib ['lzma.so.2', 'lzma.so', 'lzma']
    
    attach_function :lzma_easy_encoder, [:pointer, :uint32, :int], :int
    attach_function :lzma_code, [:pointer, :int], :int
    attach_function :lzma_stream_decoder, [:pointer, :uint64, :uint32], :int
    attach_function :lzma_end, [:pointer], :void
    
  end
  
  #The class of the error that this library raises.
  class LZMAError < StandardError
    
    #Raises an appropriate exception if +val+ isn't a liblzma success code.
    def self.raise_if_necessary(val)
      case val
      when :lzma_mem_error then raise(self, "Couldn't allocate memory!")
      when :lzma_memlimit_error then raise(self, "Decoder ran out of (allowed) memory!")
      when :lzma_format_error then raise(self, "Unrecognized file format!")
      when :lzma_options_error then raise(self, "Invalid options passed!")
      when :lzma_data_error then raise raise(self, "Archive is currupt.")
      when :lzma_buf_error then raise(self, "Buffer unusable!")
      when :lzma_prog_error then raise(self, "Program error--if you're sure your code is correct, you may have found a bug in liblzma.")
      end
    end
    
  end
  
  #The main struct of the liblzma library.
  class LZMAStream < FFI::Struct
    layout  :next_in, :pointer, #uint8
            :avail_in, :size_t,
            :total_in, :uint64,
            :next_out, :pointer, #uint8
            :avail_out, :size_t,
            :total_out, :uint64,
            :lzma_allocator, :pointer,
            :lzma_internal, :pointer,
            :reserved_ptr1, :pointer,
            :reserved_ptr2, :pointer,
            :reserved_ptr3, :pointer,
            :reserved_ptr4, :pointer,
            :reserved_int1, :uint64,
            :reserved_int2, :uint64,
            :reserved_int3, :size_t,
            :reserved_int4, :size_t,
            :reserved_enum1, :int,
            :reserved_enum2, :int
            
            #This method does basicly the same thing as the
            #LZMA_STREAM_INIT macro of liblzma. Creates a new LZMAStream
            #that has been initialized for usage. If any argument is passed,
            #it is assumed to be a FFI::Pointer to a lzma_stream structure
            #and that structure is wrapped.
            def initialize(*args)
              if args.empty? #Got a pointer, want to wrap it
                super
              else
                s = super()
                s[:next] = nil
                s[:avail_in] = 0
                s[:total_in] = 0
                s[:next_out] = nil
                s[:avail_out] = 0
                s[:total_out] = 0
                s[:lzma_allocator] = nil
                s[:lzma_internal] = nil
                s[:reserved_ptr1] = nil
                s[:reserved_ptr2] = nil
                s[:reserved_ptr3] = nil
                s[:reserved_ptr4] = nil
                s[:reserved_int1] = 0
                s[:reserved_int2] = 0
                s[:reserved_int3] = 0
                s[:reserved_int4] = 0
                s[:reserved_enum1] = LibLZMA::LZMA_RESERVED_ENUM[:lzma_reserved_enum]
                s[:reserved_enum2] = LibLZMA::LZMA_RESERVED_ENUM[:lzma_reserved_enum]
                s
              end
            end
          end
  
  #Number of bytes read in one chunk.
  CHUNK_SIZE = 4096
  #The version of this library.
  VERSION = "0.0.1".freeze
  
  class << self
    
    #call-seq:
    #  decompress_stream(io [, memory_limit [, flags ] ] )               → a_string
    #  decompress_stream(io [, memory_limit [, flags ] ] ){|chunk| ... } → an_integer
    #  decode_stream(io [, memory_limit [, flags ] ] )                   → a_string
    #  decode_stream(io [, memory_limit [, flags ] ] ){|chunk| ... }     → an_integer
    #
    #Decompresses a stream containing XZ-compressed data.
    #===Parameters
    #[io]           The IO to read from. It must be opened for reading.
    #[memory_limit] (+UINT64_MAX+) If not XZ::LibLZMA::UINT64_MAX, makes liblzma
    #               use no more memory than +memory_limit+ bytes.
    #[flags]        (<tt>[:tell_unsupported_check]</tt>) Additional flags
    #               passed to liblzma (an array). Possible flags are:
    #               [:tell_no_check] Spit out a warning if the archive hasn't an
    #                                itnegrity checksum.
    #               [:tell_unsupported_check] Spit out a warning if the archive
    #                                         has an unsupported checksum type.
    #               [:concatenated] Decompress concatenated archives.
    #[chunk]        (Block argument) One piece of decompressed data.
    #===Return value
    #If a block was given, returns the number of bytes written. Otherwise,
    #returns the decompressed data as a BINARY-encoded string.
    #===Example
    #  data = File.open("archive.xz", "rb"){|f| f.read}
    #  io = StringIO.new(data)
    #  XZ.decompress_stream(io) #=> "I AM THE DATA"
    #  io.rewind
    #  str = ""
    #  XZ.decompress_stream(io, XZ::LibLZMA::UINT64_MAX, [:tell_no_check]){|c| str << c} #=> 13
    #  str #=> "I AM THE DATA"
    #===Remarks
    #The block form is *much* better on memory usage, because it doesn't have
    #to load everything into RAM at once. If you don't know how big your
    #data gets or if you want to decompress much data, use the block form. Of
    #course you shouldn't store the data your read in RAM then as in the
    #example above.
    def decompress_stream(io, memory_limit = LibLZMA::UINT64_MAX, flags = [:tell_unsupported_check], &block)
      raise(ArgumentError, "Invalid memory limit set!") unless (0..LibLZMA::UINT64_MAX).include?(memory_limit)
      flags.each do |flag|
        raise(ArgumentError, "Unknown flag #{flag}!") unless [:tell_no_check, :tell_unsupported_check, :tell_any_check, :concatenated].include?(flag)
      end
      
      stream = LZMAStream.new
      res = LibLZMA.lzma_stream_decoder(
        stream.pointer,
        memory_limit,
        flags.inject(0){|val, flag| val | LibLZMA.const_get(:"LZMA_#{flag.to_s.upcase}")}
      )
      
      LZMAError.raise_if_necessary(res)
      
      res = ""
      if block_given?
        res = lzma_code(io, stream, &block)
      else
        lzma_code(io, stream){|chunk| res << chunk}
      end
      
      LibLZMA.lzma_end(stream.pointer)
      
      block_given? ? stream[:total_out] : res
    end
    alias decode_stream decompress_stream
    
    #call-seq:
    #  compress_stream(io [, compression_level [, check [, extreme ] ] ] ) → a_string
    #  compress_stream(io [, compression_level [, check [, extreme ] ] ] ){|chunk| ... } → an_integer
    #  encode_stream(io [, compression_level [, check [, extreme ] ] ] ) → a_string
    #  encode_stream(io [, compression_level [, check [, extreme ] ] ] ){|chunk| ... } → an_integer
    #
    #Compresses a stream of data into XZ-compressed data.
    #===Parameters
    #[io]                The IO to read the data from. Must be opened for
    #                    reading.
    #[compression_level] (6) Compression strength. Higher values indicate a
    #                    smaller result, but longer compression time. Maximum
    #                    is 9.
    #[check]             (:crc64) The checksum algorithm to use for verifying
    #                    the data inside the archive. Possible values are:
    #                    * :none
    #                    * :crc32
    #                    * :crc64
    #                    * :sha256
    #[extreme]           (false) Tries to get the last bit out of the
    #                    compression. This may succeed, but you can end
    #                    up with *very* long computation times.
    #[chunk]             (Block argument) One piece of compressed data.
    #===Return value
    #If a block was given, returns the number of bytes written. Otherwise,
    #returns the compressed data as a BINARY-encoded string.
    #===Example
    #  data = File.read("file.txt")
    #  i = StringIO.new(data)
    #  XZ.compress_stream(i) #=> Some binary blob
    #  i.rewind
    #  str = ""
    #  XZ.compress_stream(i, 4, :sha256){|c| str << c} #=> 123
    #  str #=> Some binary blob
    #===Remarks
    #The block form is *much* better on memory usage, because it doesn't have
    #to load everything into RAM at once. If you don't know how big your
    #data gets or if you want to compress much data, use the block form. Of
    #course you shouldn't store the data your read in RAM then as in the
    #example above.
    def compress_stream(io, compression_level = 6, check = :crc64, extreme = false, &block)
      raise(ArgumentError, "Invalid compression level!") unless (0..9).include?(compression_level)
      raise(ArgumentError, "Invalid checksum specified!") unless [:none, :crc32, :crc64, :sha256].include?(check)
      
      stream = LZMAStream.new
      res = LibLZMA.lzma_easy_encoder(
      stream.pointer,
      compression_level | (extreme ? LibLZMA::LZMA_PRESET_EXTREME : 0),
      LibLZMA::LZMA_CHECK[:"lzma_check_#{check}"]
      )
      
      LZMAError.raise_if_necessary(res)
      
      res = ""
      if block_given?
        res = lzma_code(io, stream, &block)
      else
        lzma_code(io, stream){|chunk| res << chunk}
      end
      
      LibLZMA.lzma_end(stream.pointer)
      
      block_given? ? stream[:total_out] : res
    end
    alias encode_stream compress_stream
    
    #Compresses +in_file+ and writes the result to +out_file+.
    #===Parameters
    #[in_file]  The path to the file to read from.
    #[out_file] The path of the file to write to. If it exists, it will be
    #           overwritten.
    #For the other parameters, see the compress_stream method.
    #===Return value
    #The number of bytes written, i.e. the size of the archive.
    #===Example
    #  XZ.compress("myfile.txt", "myfile.txt.xz")
    #  XZ.compress("myarchive.tar", "myarchive.tar.xz")
    #===Remarks
    #This method is safe to use with big files, because files are not loaded
    #into memory completely at once.
    def compress_file(in_file, out_file, compression_level = 6, check = :crc64, extreme = false)
      File.open(in_file, "rb") do |i_file|
        File.open(out_file, "wb") do |o_file|
          compress_stream(i_file, compression_level, check, extreme) do |chunk|
            o_file.write(chunk)
          end
        end
      end
    end
    
    #Compresses arbitrary data using the XZ algorithm.
    #===Parameters
    #[str] The data to compress.
    #For the other parameters, see the compress_stream method.
    #===Return value
    #The compressed data as a BINARY-encoded string.
    #===Example
    #  data = "I love Ruby"
    #  comp = XZ.compress(data) #=> binary blob
    #===Remarks
    #Don't use this method for big amounts of data--you may run out of
    #memory. Use compress_file or compress_stream instead.
    def compress(str, compression_level = 6, check = :crc64, extreme = false)
      raise(NotImplementedError, "StringIO isn't available!") unless defined? StringIO
      s = StringIO.new(str)
      compress_stream(s, compression_level, check, extreme)
    end
    
    #Decompresses data in XZ format.
    #===Parameters
    #[str] The data to decompress.
    #For the other parameters, see the decompress_stream method.
    #===Return value
    #The decompressed data as a BINARY-encoded string.
    #===Example
    #  comp = File.open("data.xz", "rb"){|f| f.read}
    #  data = XZ.decompress(comp) #=> "I love Ruby"
    #===Remarks
    #Don't use this method for big amounts of data--you may run out of
    #memory. Use decompress_file or decompress_stream instead.
    def decompress(str, memory_limit = LibLZMA::UINT64_MAX, flags = [:tell_unsupported_check])
      raise(NotImplementedError, "StringIO isn't available!") unless defined? StringIO
      s = StringIO.new(str)
      decompress_stream(s, memory_limit, flags)
    end
    
    #Decompresses +in_file+ and writes the result to +out_file+.
    #===Parameters
    #[in_file]  The path to the file to read from.
    #[out_file] The path of the file to write to. If it exists, it will
    #           be overwritten.
    #For the other parameters, see the decompress_stream method.
    #===Return value
    #The number of bytes written, i.e. the size of the uncompressed data.
    #===Example
    #  XZ.decompres("myfile.txt.xz", "myfile.txt")
    #  XZ.decompress("myarchive.tar.xz", "myarchive.tar")
    #===Remarks
    #This method is safe to use with big files, because files are not loaded
    #into memory completely at once.
    def decompress_file(in_file, out_file, memory_limit = LibLZMA::UINT64_MAX, flags = [:tell_unsupported_check])
      File.open(in_file, "rb") do |i_file|
        File.open(out_file, "wb") do |o_file|
          decompress_stream(i_file, memory_limit, flags) do |chunk|
            o_file.write(chunk)
          end
        end
      end
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
    
    #This method does the heavy work of (de-)compressing a stream. It takes
    #an IO object to read data from (that means the IO must be opened
    #for reading) and a XZ::LZMAStream object that is used to (de-)compress
    #the data. Furthermore this method takes a block which gets passed
    #the (de-)compressed data in chunks one at a time--this is needed to allow
    #(de-)compressing of very large files that can't be loaded fully into
    #memory.
    def lzma_code(io, stream)
      input_buffer_p = FFI::MemoryPointer.new(CHUNK_SIZE)
      output_buffer_p = FFI::MemoryPointer.new(CHUNK_SIZE)
      
      while str = io.read(CHUNK_SIZE)
        input_buffer_p.write_string(str)
        
        #Set the data for compressing
        stream[:next_in] = input_buffer_p
        stream[:avail_in] = binary_size(str)
        
        #Now loop until we gathered all the data in stream[:next_out]. Depending on the
        #amount of data, this may not fit into the buffer, meaning that we have to
        #provide a pointer to a "new" buffer that liblzma can write into. Since
        #liblzma already set stream[:avail_in] to 0 in the first iteration, the extra call to the
        #lzma_code() function doesn't hurt (indeed the pipe_comp example from
        #liblzma handles it this way too). Sometimes it happens that the compressed data
        #is bigger than the original (notably when the amount of data to compress
        #is small)
        loop do
          #Prepare for getting the compressed_data
          stream[:next_out] = output_buffer_p
          stream[:avail_out] = CHUNK_SIZE
          
          #Compress the data
          res = if io.eof?
            LibLZMA.lzma_code(stream.pointer, LibLZMA::LZMA_ACTION[:lzma_finish])
          else
            LibLZMA.lzma_code(stream.pointer, LibLZMA::LZMA_ACTION[:lzma_run])
          end
          check_lzma_code_retval(res)
          
          #Write the compressed data
          data = output_buffer_p.read_string(CHUNK_SIZE - stream[:avail_out])
          yield(data)
          
          #If the buffer is completely filled, it's likely that there is
          #more data liblzma wants to hand to us. Start a new iteration,
          #but don't provide new input data.
          break unless stream[:avail_out] == 0
        end #loop
      end #while
    end #lzma_code
    
    #Checks for errors and warnings that can be derived from the return
    #value of the lzma_code() function and shows them if necessary.
    def check_lzma_code_retval(code)
      e = LibLZMA::LZMA_RET
      case code
      when e[:lzma_no_check] then warn("Couldn't verify archive integrity--archive has not integrity checksum.")
      when e[:lzma_unsupported_check] then warn("Couldn't verify archive integrity--archive has an unsupported integrity checksum.")
      when e[:lzma_get_check] then nil #This isn't useful for us. It indicates that the checksum type is now known.
      else
        LZMAError.raise_if_necessary(code)
      end
    end
    
  end #class << self
  
end

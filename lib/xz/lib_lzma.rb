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

module XZ

  # This module wraps functions and enums provided by liblzma.
  # It contains the direct mapping to the underlying C functions;
  # you should never have to use this. It's the lowlevel API
  # the other methods provided by ruby-xz are based on.
  module LibLZMA
    extend Fiddle::Importer
    extend XZ::FiddleHelper

    dlloadanyof 'liblzma.so.5', 'liblzma.so', 'liblzma.5.dylib', 'liblzma.dylib', 'liblzma'

    typealias "uint32_t", "unsigned int"
    typealias "uint64_t", "unsigned long long"

    # lzma_ret enum
    enum :LZMA_OK, 0, :LZMA_STREAM_END, 1, :LZMA_NO_CHECK, 2,
         :LZMA_UNSUPPORTED_CHECK, 3, :LZMA_GET_CHECK, 4,
         :LZMA_MEM_ERROR, 5, :LZMA_MEMLIMIT_ERROR, 6,
         :LZMA_FORMAT_ERROR, 7, :LZMA_OPTIONS_ERROR, 8,
         :LZMA_DATA_ERROR, 9, :LZMA_BUF_ERROR, 10,
         :LZMA_PROG_ERROR, 11

    # lzma_action enum
    enum :LZMA_RUN, 0, :LZMA_SYNC_FLUSH, 1,
         :LZMA_FULL_FLUSH, 2, :LZMA_FULL_BARRIER, 4,
         :LZMA_FINISH, 3

    # The maximum value of an uint64_t, as defined by liblzma.
    # Should be the same as
    #   (2 ** 64) - 1
    UINT64_MAX = 18446744073709551615

    # Activates extreme compression. Same as xz's "-e" commandline switch.
    LZMA_PRESET_EXTREME = 1 << 31

    LZMA_TELL_NO_CHECK          = 0x01
    LZMA_TELL_UNSUPPORTED_CHECK = 0x02
    LZMA_TELL_ANY_CHECK         = 0x04
    LZMA_CONCATENATED           = 0x08
    LZMA_IGNORE_CHECK           = 0x10

    # For access convenience of the above flags.
    LZMA_DECODE_FLAGS = {
      :tell_no_check          => LZMA_TELL_NO_CHECK,
      :tell_unsupported_check => LZMA_TELL_UNSUPPORTED_CHECK,
      :tell_any_check         => LZMA_TELL_ANY_CHECK,
      :concatenated           => LZMA_CONCATENATED,
      :ignore_check           => LZMA_IGNORE_CHECK
    }.freeze

    # Placeholder enum used by liblzma for later additions.
    enum :LZMA_RESERVED_ENUM, 0

    # lzma_check enum
    enum :LZMA_CHECK_NONE, 0, :LZMA_CHECK_CRC32, 1,
         :LZMA_CHECK_CRC64, 4, :LZMA_CHECK_SHA256, 10

    # Aliases for the enums as fiddle only understands plain int
    typealias "lzma_ret", "int"
    typealias "lzma_check", "int"
    typealias "lzma_action", "int"
    typealias "lzma_reserved_enum", "int"

    # lzma_stream struct. When creating one with ::malloc, use
    # ::LZMA_STREAM_INIT to make it ready for use.
    #
    # This is a Fiddle::CStruct. As such, this has a class method
    # ::malloc for allocating an instance of it on the heap, and
    # instances of it have a #to_ptr method that returns a
    # Fiddle::Pointer. That pointer needs to be freed with
    # Fiddle::free if the instance was created with ::malloc.
    # To wrap an existing instance, call ::new with the
    # Fiddle::Pointer to wrap as an argument.
    LZMAStream = struct [
      "uint8_t* next_in",
      "size_t avail_in",
      "uint64_t total_in",
      "uint8_t* next_out",
      "size_t avail_out",
      "uint64_t total_out",
      "void* allocator",
      "void* internal",
      "void* reserved_ptr1",
      "void* reserved_ptr2",
      "void* reserved_ptr3",
      "void* reserved_ptr4",
      "uint64_t reserved_int1",
      "uint64_t reserved_int2",
      "size_t reserved_int3",
      "size_t reserved_int4",
      "lzma_reserved_enum reserved_enum1",
      "lzma_reserved_enum reserved_enum2"
    ]

    # This method does basicly the same thing as the
    # LZMA_STREAM_INIT macro of liblzma. Pass it an instance of
    # LZMAStream that has not been initialised for use.
    # The intended use of this method is:
    #
    #   stream = LibLZMA::LZMAStream.malloc # ::malloc is provided by fiddle
    #   LibLZMA.LZMA_STREAM_INIT(stream)
    #   # ...do something with the stream...
    #   Fiddle.free(stream.to_ptr)
    def self.LZMA_STREAM_INIT(stream)
      stream.next_in        = nil
      stream.avail_in       = 0
      stream.total_in       = 0
      stream.next_out       = nil
      stream.avail_out      = 0
      stream.total_out      = 0
      stream.allocator      = nil
      stream.internal       = nil
      stream.reserved_ptr1  = nil
      stream.reserved_ptr2  = nil
      stream.reserved_ptr3  = nil
      stream.reserved_ptr4  = nil
      stream.reserved_int1  = 0
      stream.reserved_int2  = 0
      stream.reserved_int3  = 0
      stream.reserved_int4  = 0
      stream.reserved_enum1 = LZMA_RESERVED_ENUM
      stream.reserved_enum2 = LZMA_RESERVED_ENUM
      stream
    end

    extern "lzma_ret lzma_easy_encoder(lzma_stream*, uint32_t, lzma_check)"
    extern "lzma_ret lzma_code(lzma_stream*, lzma_action)"
    extern "lzma_ret lzma_stream_decoder(lzma_stream*, uint64_t, uint32_t)"
    extern "void lzma_end(lzma_stream*)"

  end

  # The class of the error that this library raises.
  class LZMAError < StandardError

    # Raises an appropriate exception if +val+ isn't a liblzma success code.
    def self.raise_if_necessary(val)
      case val
      when LibLZMA::LZMA_MEM_ERROR      then raise(self, "Couldn't allocate memory!")
      when LibLZMA::LZMA_MEMLIMIT_ERROR then raise(self, "Decoder ran out of (allowed) memory!")
      when LibLZMA::LZMA_FORMAT_ERROR   then raise(self, "Unrecognized file format!")
      when LibLZMA::LZMA_OPTIONS_ERROR  then raise(self, "Invalid options passed!")
      when LibLZMA::LZMA_DATA_ERROR     then raise(self, "Archive is currupt.")
      when LibLZMA::LZMA_BUF_ERROR      then raise(self, "Buffer unusable!")
      when LibLZMA::LZMA_PROG_ERROR     then raise(self, "Program error--if you're sure your code is correct, you may have found a bug in liblzma.")
      end
    end

  end

end

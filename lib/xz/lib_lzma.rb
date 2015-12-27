# -*- coding: utf-8 -*-
#--
# The MIT License
#
# Basic liblzma-bindings for Ruby.
#
# Copyright © 2011,2013,2015 Marvin Gülker et al.
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

  # This module wraps functions and enums used by liblzma.
  module LibLZMA
    extend FFI::Library

    # The maximum value of an uint64_t, as defined by liblzma.
    # Should be the same as
    #   (2 ** 64) - 1
    UINT64_MAX = 18446744073709551615

    # Activates extreme compression. Same as xz's "-e" commandline switch.
    LZMA_PRESET_EXTREME = 1 << 31

    LZMA_TELL_NO_CHECK          = 0x02
    LZMA_TELL_UNSUPPORTED_CHECK = 0x02
    LZMA_TELL_ANY_CHECK         = 0x04
    LZMA_CONCATENATED           = 0x08

    # For access convenience of the above flags.
    LZMA_DECODE_FLAGS = {
      :tell_no_check          => LZMA_TELL_NO_CHECK,
      :tell_unsupported_check => LZMA_TELL_UNSUPPORTED_CHECK,
      :tell_any_check         => LZMA_TELL_ANY_CHECK,
      :concatenated           => LZMA_CONCATENATED
    }.freeze

    # Placeholder enum used by liblzma for later additions.
    LZMA_RESERVED_ENUM = enum :lzma_reserved_enum, 0

    # Actions that can be passed to the lzma_code() function.
    LZMA_ACTION = enum  :lzma_run, 0,
    :lzma_sync_flush,
    :lzma_full_flush,
    :lzma_finish

    # Integrity check algorithms supported by liblzma.
    LZMA_CHECK = enum :lzma_check_none,   0,
    :lzma_check_crc32,  1,
    :lzma_check_crc64,  4,
    :lzma_check_sha256, 10

    # Possible return values of liblzma functions.
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

    ffi_lib ['lzma.so.5', 'lzma.so', 'lzma']

    attach_function :lzma_easy_encoder, [:pointer, :uint32, :int], :int, :blocking => true
    attach_function :lzma_code, [:pointer, :int], :int, :blocking => true
    attach_function :lzma_stream_decoder, [:pointer, :uint64, :uint32], :int, :blocking => true
    attach_function :lzma_end, [:pointer], :void, :blocking => true

  end

  # The class of the error that this library raises.
  class LZMAError < StandardError

    # Raises an appropriate exception if +val+ isn't a liblzma success code.
    def self.raise_if_necessary(val)
      case LibLZMA::LZMA_RET[val]
      when :lzma_mem_error      then raise(self, "Couldn't allocate memory!")
      when :lzma_memlimit_error then raise(self, "Decoder ran out of (allowed) memory!")
      when :lzma_format_error   then raise(self, "Unrecognized file format!")
      when :lzma_options_error  then raise(self, "Invalid options passed!")
      when :lzma_data_error     then raise(self, "Archive is currupt.")
      when :lzma_buf_error      then raise(self, "Buffer unusable!")
      when :lzma_prog_error     then raise(self, "Program error--if you're sure your code is correct, you may have found a bug in liblzma.")
      end
    end

  end

  # The main struct of the liblzma library.
  class LZMAStream < FFI::Struct
    layout :next_in, :pointer, #uint8
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

    # This method does basicly the same thing as the
    # LZMA_STREAM_INIT macro of liblzma. Creates a new LZMAStream
    # that has been initialized for usage. If any argument is passed,
    # it is assumed to be a FFI::Pointer to a lzma_stream structure
    # and that structure is wrapped.
    def initialize(*args)
      if !args.empty? #Got a pointer, want to wrap it
        super
      else
        s = super()
        s[:next_in]        = nil
        s[:avail_in]       = 0
        s[:total_in]       = 0
        s[:next_out]       = nil
        s[:avail_out]      = 0
        s[:total_out]      = 0
        s[:lzma_allocator] = nil
        s[:lzma_internal]  = nil
        s[:reserved_ptr1]  = nil
        s[:reserved_ptr2]  = nil
        s[:reserved_ptr3]  = nil
        s[:reserved_ptr4]  = nil
        s[:reserved_int1]  = 0
        s[:reserved_int2]  = 0
        s[:reserved_int3]  = 0
        s[:reserved_int4]  = 0
        s[:reserved_enum1] = LibLZMA::LZMA_RESERVED_ENUM[:lzma_reserved_enum]
        s[:reserved_enum2] = LibLZMA::LZMA_RESERVED_ENUM[:lzma_reserved_enum]
        s
      end
    end
  end

end

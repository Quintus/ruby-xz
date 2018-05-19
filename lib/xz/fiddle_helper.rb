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

  # This is an internal API not meant for users of ruby-xz.
  # This mixin modules defines some helper functions on top
  # of Fiddle's functionality.
  module FiddleHelper # :nodoc:

    # Define constants that have numeric constants assigned as if
    # it was a C enum definition. You can specificy values explicitely
    # or rely on the implicit incrementation; the first implicit value
    # is zero.
    #
    # Example:
    #
    #   enum :FOO, :BAR, 5, :BAZ
    #
    # This defines a constant FOO with value 0, BAR with value 5, BAZ
    # with value 6.
    def enum(*args)
      @next_enum_val = 0 # First value of an enum is 0 in C

      args.each_cons(2) do |val1, val2|
        next if val1.respond_to?(:to_int)

        if val2.respond_to?(:to_int)
          const_set(val1, val2.to_int)
          @next_enum_val = val2.to_int + 1
        else
          const_set(val1, @next_enum_val)
          @next_enum_val += 1
        end
      end

      # Cater for the last element in case it is not an explicit
      # value that has already been assigned above.
      unless args.last.respond_to?(:to_int)
        const_set(args.last, @next_enum_val)
      end

      @next_enum_val = 0
      nil
    end

    # Try loading any of the given names as a shared
    # object. Raises Fiddle::DLError if none can
    # be opened.
    def dlloadanyof(*names)
      names.each do |name|
        begin
          dlload(name)
        rescue Fiddle::DLError
          # Continue with next one
        else
          # Success
          return name
        end
      end

      raise Fiddle::DLError, "Failed to open any of these shared object files: #{names.join(', ')}"
    end

  end

end

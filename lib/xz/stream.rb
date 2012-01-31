# -*- coding: utf-8 -*-

#The base class for XZ::StreamReader and XZ::StreamWriter.
#This is an abstract class that is not meant to be used
#directly; if you try, you will soon recognise that you’ve
#created a quite limited object ;-). You can, however, test
#against this class in <tt>kind_of?</tt> tests.
#
#XZ::StreamReader and XZ::StreamWriter are IO-like classes that
#allow you to access XZ-compressed data the same way you access
#an IO-object, easily allowing to fool other libraries that expect
#IO objects. The most noticable example for this may be reading
#and writing XZ-compressed tarballs; see XZ::StreamReader and
#XZ::StreamWriter for respective examples.
#
#Neither this class nor its subclasses document the IO-methods
#they contain--this is due to the reason that they include the
#great IO::Like module that provides all the necessary IO methods
#based on a few methods you define. For all defined IO methods,
#see the +io-like+ gem’s documentation.
class XZ::Stream
  include IO::Like

  #Creates a new instance of this class. Don’t use this directly,
  #it’s only called by subclasses’ ::new methods.
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

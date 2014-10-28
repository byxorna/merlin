require 'merlin'

module Merlin
  module Util
    # Takes an array of pairs, or a hash of input file to output file, and an output directory
    # input file is made into an absolute path. if relative, uses pwd
    # output file is made into an absolute path. if relative, uses outdir
    # returns a hash of input file => output file
    def self.make_absolute_path_hash input_output, outdir
      # if input_output is a list, convert to list of pairs of input, output
      if input_output.is_a? Enumerable and ! input_output.is_a? Hash
        input_output = input_output.map{|f| [f,f]}
      else
        input_output = input_output.to_a  # flatten down to array of pairs
      end
      pairs = input_output.map do |infile,outfile|
        # input file is always relative to pwd, so just blindly absolutify
        abs_infile = File.absolute_path(infile)
        # output file is relative to
        abs_outfile = if Pathname.new(outfile).absolute?
            outfile # just use the absolute pathname for the output file
          else
            File.join outdir, outfile # it is relative to outdir
          end
        [abs_infile, abs_outfile]
      end
      Hash[pairs]
    end
  end
end

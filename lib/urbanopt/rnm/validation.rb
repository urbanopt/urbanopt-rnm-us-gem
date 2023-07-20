# *********************************************************************************
# URBANopt™, Copyright © Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-rnm-us-gem/blob/develop/LICENSE.md
# *********************************************************************************

require 'urbanopt/rnm/logger'

module URBANopt
  module RNM
    # Class for OpenDSS validation (runs python script)
    class Validation
      ##
      # Initialize attributes: ++run directory+
      ##
      # [parameters:]
      # * +rnm_dirname+ - _String_ - name of RNM-US directory that will contain the input files (within the scenario directory)
      def initialize(rnm_full_path,b_numeric_ids)
        # absolute path
        @rnm_full_path = rnm_full_path
        @opendss_full_path=File.join(@rnm_full_path,'results/OpenDSS')
        @b_numeric_ids=b_numeric_ids
        if !Dir.exist?(@opendss_full_path)
            puts 'Error: folder does not exist'+@opendss_full_path
            raise 'No OpenDSS directory found for this scenario...run simulation first.'
        end
      end


      ##
      # Run validation
      ##
      def run_validation()
        puts "Initiating OpenDSS validation in folder"
        puts @opendss_full_path
        puts "This can take several minutes"
        # puts `python ./lib/urbanopt/rnm/validation/main_validation.py #{@rnm_full_path}`
        log=`python ./lib/urbanopt/rnm/validation/main_validation.py #{@opendss_full_path} #{@b_numeric_ids}`
        puts log
      end
    end
  end
end

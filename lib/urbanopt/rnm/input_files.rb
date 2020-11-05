# *********************************************************************************
# URBANopt (tm), Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC, and other
# contributors. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
# *********************************************************************************

module URBANopt
  module RNM
		class InputFiles

	    ##
	    # Initialize InputFiles attributs: +run_dir+, +feature_file_path+, +rnm_dirname+ 
	    ##
	    # [parameters:]
	    # * +run_dir+ - _String_ - Full path to directory for simulation of this scenario
	    # * +feature_file_path+ - _String_ - Full path to GeoJSON feature file containing features and streets for simulation.
	    # * +rnm_dirname+ - _String_ - name of RNM-US directory that will contain the input files (within the scenario directory)
	    ##
	    def initialize(run_dir, feature_file_path, rnm_dirname='rnm-us')
	    	@run_dir = run_dir
	    	@feature_file_path = feature_file_path
	    	@rnm_dirname = rnm_dirname

	    	# initialize RNM directory
        if !Dir.exist?(File.join(@run_dir, @rnm_dirname))
          FileUtils.mkdir_p(File.join(@run_dir, @rnm_dirname))
          @@logger.info("Created directory: " + File.join(@run_dir, @rnm_dirname))
        end

	    end

	    ##
	    # Create the files that are required as input in RNM-US. (streetmap.txt, customers.txt, customers_ext.txt)
	    ##
	    def create()
	       # creating the arrays that will be filled with the data needed for the RNM-US input txt files
		    data_customers_ext = []
		    data_customers = []
		    customers_coordinates = []
		    
		    # the streetmap GEOjson file is loaded and a method is called to extract the required information regarding the street and building location
		    street_coordinates, customers_coordinates, tot_buildings = URBANopt::RNM::Dataload.new.coordinates_file_load(File.read(@feature_file_path))
		    
		    # the csv and json feature_report files are loaded for each building and the building location is passed as an argument in order to obtain the customer_ext array with the required information (e.g. location, electricity consumption)
        # TODO: need to use ID of buildings (from geojson file) as directory name
        # reports are always in 'feature_reports' directory now
        for j in 0..tot_buildings-1
          file_path = File.join(@run_dir, "#{j+1}", 'feature_reports', 'default_feature_report')
		   		data_customers_ext[j], data_customers[j] = URBANopt::RNM::Dataload.new.customer_files_load(file_path + ".csv", File.read(file_path + ".json"), customers_coordinates[j])
        end
        
        # creating the streetmap.txt, cutomers.txt and customers_ext.txt files in the folder Inputs in the RNM folder
		    File.open(File.join(@run_dir, @rnm_dirname, "streetmap.txt"), "w+") do |f|
			    f.puts(street_coordinates.map { |x| x.join(';') })
		    end
		    File.open(File.join(@run_dir, @rnm_dirname, "customers.txt"), "w+") do |f|
			    f.puts(data_customers.map { |x| x.join(';') })
		    end
		    File.open(File.join(@run_dir, @rnm_dirname, "customers_ext.txt"), "w+") do |g|
			    g.puts(data_customers_ext.map { |w| w.join(';') })
	      end
	    end

	    ##
	    # Delete the RNM-US input files directory
	    ##
	    def delete()
	    	if Dir.exist?(File.join(@run_dir, @rnm_dirname))
	    		FileUtils.rm_rf(File.join(@run_dir, @rnm_dirname))
	    	end
	    end
		end
  end
end

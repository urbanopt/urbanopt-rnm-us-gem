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

require 'urbanopt/rnm/logger'

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
	    def initialize(run_dir, feature_file_path, extended_catalog_path='/path', average_building_peak_catalog_path='path', rnm_dirname='rnm-us', reopt=false, opendss_catalog=false)
	    	@run_dir = run_dir
	    	@feature_file_path = feature_file_path
	    	@rnm_dirname = rnm_dirname
            @extended_catalog_path = extended_catalog_path
            @average_building_peak_catalog_path = average_building_peak_catalog_path
            @reopt = reopt
            @opendss_catalog = opendss_catalog
				# initialize @@logger
        @@logger ||= URBANopt::RNM.logger

	    	# initialize RNM directory
            if !Dir.exist?(File.join(@run_dir, @rnm_dirname))
                FileUtils.mkdir_p(File.join(@run_dir, @rnm_dirname))
                @@logger.info("Created directory: " + File.join(@run_dir, @rnm_dirname))
            end
	    end
        def generate_opendss_catalog()
            #put the script
            #place this new file created in the rnm-us folder outside the inputs folder
        end
	    ##
	    # Create the files that are required as input in RNM-US. (streetmap.txt, customers.txt, customers_ext.txt)
	    ##
	    def create()
	       # creating the arrays that will be filled with the data needed for the RNM-US input txt files
		    data_customers_ext = []
		    data_customers = []
		    customers_coordinates = []
            profile_customer_p = []
            profile_customer_q = []
            profile_customer_q_ext = []
            profile_customer_p_ext = []
		    # the streetmap GEOjson file is loaded and a method is called to extract the required information regarding the street and building location
		    street_coordinates, customers_coordinates, coordinates_buildings, tot_buildings, building_ids, substation_location, only_lv_consumers = URBANopt::RNM::Streetmap.new.coordinates_file_load(File.read(@feature_file_path)) #maybe I can convert this with an hash, with all this info
		    puts("BUILDING IDS: #{building_ids}")
            n = 0 #counter per number of consumers' nodes
            if @reopt
                data_dg = []
                dg_profile_p = []
                dg_profile_q = []
                profile_dg_p_extended = []
                profile_dg_q_extended = []
                if !File.join(@run_dir, 'feature_optimization').nil?
                    scenario_report_path = File.join(@run_dir, 'feature_optimization')
                else 
                    raise 'scenario_report is not valid' #be more clear scenario report is not found
                end

            else
                if !File.join(@run_dir, 'scenario_report').nil?
                    scenario_report_path = File.join(@run_dir, 'default_scenario_report')
                else
                    raise 'scenario_report is not valid'
                end
            else 
            hours =  URBANopt::RNM::Consumers.new(@reopt) # accroding to the 2 extreme hours of the year (maximum net demand and maximum net generation) the distribution network is planned
            hours.scenario_report_results(scenario_report_path + ".csv")
            if only_lv_consumers == true
                (0..tot_buildings-1).each do |j|
                    # use building_ids lookup to get name of results directory
                    # reports will be in 'feature_reports' directory 
                    puts("j: #{j}")
                    puts("path: #{building_ids[j]}")
                    if @reopt #the condition if there s reopt or not can be mooved above
                        file_path = File.join(@run_dir, "#{building_ids[j]}", 'feature_reports', 'feature_optimization')
                        data_customers_ext, data_customers, data_dg[j], profile_customer_p, profile_customer_q, profile_customer_p_ext, profile_customer_q_ext, dg_profile_p[j], dg_profile_q[j], profile_dg_p_extended[j], profile_dg_q_extended[j], n  = URBANopt::RNM::Dataload.customer_files_load(file_path + ".csv", File.read(file_path + ".json"), customers_coordinates[j], coordinates_buildings[j], data_customers, data_customers_ext, n, average_building_peak_catalog_path, profile_customer_p, profile_customer_q, profile_customer_p_ext, profile_customer_q_ext, hours))
                    else
                        file_path = File.join(@run_dir, "#{building_ids[j]}", 'feature_reports', 'default_feature_report')
                        data_customers_ext, data_customers, profile_customer_p, profile_customer_q, profile_customer_p_ext, profile_customer_q_ext, n  = URBANopt::RNM::Consumers.customer_files_load(file_path + ".csv", File.read(file_path + ".json"), customers_coordinates[j], coordinates_buildings[j], data_customers, data_customers_ext, n, average_building_peak_catalog_path, profile_customer_p, profile_customer_q, profile_customer_p_ext, profile_customer_q_ext, hours))
                    end
                end
            else
                (0..tot_buildings-1).each do |j|
                    # use building_ids lookup to get name of results directory
                    # reports will be in 'feature_reports' directory 
                    puts("j: #{j}")
                    puts("path: #{building_ids[j]}")
                    if @run_dir.include? 'reopt' #the condition if there s reopt or not can be mooved above
                        file_path = File.join(@run_dir, "#{building_ids[j]}", 'feature_reports', 'feature_optimization')
                        data_customers_ext[j], data_customers[j], data_dg[j], profile_customer_p[j], profile_customer_q[j], profile_customer_p_ext[j], profile_customer_q_ext[j], dg_profile_p[j], dg_profile_q[j], profile_dg_p_extended[j], profile_dg_q_extended[j] = URBANopt::RNM::Consumers.customer_files_load(file_path + ".csv", File.read(file_path + ".json"), costumers_coordinates[j], hours)
                    else
                        file_path = File.join(@run_dir, "#{building_ids[j]}", 'feature_reports', 'default_feature_report')
                        data_customers_ext[j], data_customers[j], profile_customer_p[j], profile_customer_q[j], profile_customer_p_ext[j], profile_customer_q_ext[j]  = URBANopt::RNM::Consumers.customer_files_load(file_path + ".csv", File.read(file_path + ".json"), customers_coordinates[j], hours))
                    end
                end
            end
            #call the opendss_catalog_function-->if @opendss_catalog
        
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
            File.open(output['rnm_folder'] + "cust_profile_p.txt", "w+") do |g|
                g.puts(profile_customer_p.map { |w| w.join(';') })
            end
            File.open(output['rnm_folder'] + "cust_profile_q.txt", "w+") do |g|
                g.puts(profile_customer_q.map { |w| w.join(';') })
            end
            File.open(output['rnm_folder'] + "cust_profile_q_extendido.txt", "w+") do |g|
                g.puts(profile_customer_q_ext.map { |w| w.join(';') })
            end
            File.open(output['rnm_folder'] + "cust_profile_p_extendido.txt", "w+") do |g|
                g.puts(profile_customer_p_ext.map { |w| w.join(';') })
            end
            if substation_location != 'nil'
                File.open(output['rnm_folder'] + "primary_substations.txt", "w+") do |f|
                    f.puts(substation_location.map { |x| x.join(';') })
                end
            end
            if @run_dir.include? 'reopt'
                File.open(output['rnm_folder'] + "generators.txt", "w+") do |g|
                    g.puts(data_dg.map { |w| w.join(';') })
                end
                # creating profiles txt files
                File.open(output['rnm_folder'] + "gen_profile_p.txt", "w+") do |g|
                    g.puts(dg_profile_p.map { |w| w.join(';') })
                end
                File.open(output['rnm_folder'] + "gen_profile_q.txt", "w+") do |g|
                    g.puts(dg_profile_q.map { |w| w.join(';') })
                end
                File.open(output['rnm_folder'] + "gen_profile_q_extendido.txt", "w+") do |g|
                    g.puts(profile_dg_q_extended.map { |w| w.join(';') })
                end
                File.open(output['rnm_folder'] + "gen_profile_p_extendido.txt", "w+") do |g|
                    g.puts(profile_dg_p_extended.map { |w| w.join(';') })
                end
            end
            #create the ficheros_entrada file and understand where to include the extended scenario script to convert to rnm-us catalog
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
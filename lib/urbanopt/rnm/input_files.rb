# *********************************************************************************
# URBANopt (tm), Copyright (c) 2019-2022, Alliance for Sustainable Energy, LLC, and other
# contributors. All rights reserved.

# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:

# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.

# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.

# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.

# Redistribution of this software, without modification, must refer to the software
# by the same designation. Redistribution of a modified version of this software
# (i) may not refer to the modified version by the same designation, or by any
# confusingly similar designation, and (ii) must refer to the underlying software
# originally provided by Alliance as "URBANopt". Except to comply with the foregoing,
# the term "URBANopt", or any confusingly similar designation may not be used to
# refer to any modified version of this software or any modified version of the
# underlying software originally provided by Alliance without the prior written
# consent of Alliance.

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

require 'csv'
require 'json'
require 'urbanopt/rnm/logger'
require 'urbanopt/geojson'

module URBANopt
  module RNM
    class InputFiles
      ##
      # Initialize InputFiles attributes: +run_dir+, +feature_file_path+, +reopt+, +extended_catalog_path+, +average_building_peak_catalog_path+, +rnm_dirname+, +opendss_catalog+
      ##
      # [parameters:]
      # * +run_dir+ - _String_ - Full path to directory for simulation of this scenario
      # * +feature_file_path+ - _String_ - Full path to GeoJSON feature file containing features and streets for simulation.
      # * +extended_catalog_path+ - _String_ - Full path to the extended_catalog which include all the info about electric equipment and RNM-US parameters
      # * +average_building_peak_catalog_path+ - _String_ - Full path to the catalog providing average peak building consumption per floor area and average floor area per building type
      # * +reopt+ - _Boolean_ - Input command from the user to either include or not DG capabilities in planning the network, if REopt was ran before
      # * +opendss_catalog+ - _Boolean_ - Input command from the user to either run or not the opendss_conversion_script to convert the extended_catalog in OpenDSS catalog
      # * +rnm_dirname+ - _String_ - name of RNM-US directory that will contain the input files (within the scenario directory)
      ##
      def initialize(run_dir, scenario_features, feature_file, extended_catalog_path, average_building_peak_catalog_path, reopt: false, opendss_catalog: true, rnm_dirname: 'rnm-us')
        @run_dir = run_dir
        @feature_file = feature_file
        @scenario_features = scenario_features
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
          @@logger.info("Created directory: #{File.join(@run_dir, @rnm_dirname)}")
        end
      end

      # finding the limits on LV defined by the equipments in the catalog
      def catalog_limits
        catalog = JSON.parse(File.read(@extended_catalog_path))
        limit = Hash.new(0)
        limit_lines = Hash.new(0)
        limit_trafo = Hash.new(0)
        # evaluating first all the LV power lines included in the extended catalog and finding the LV 3-phase and single-phase
        # lines with the highest capacity
        catalog['LINES'][1].each do |key, v|
          (0..catalog['LINES'][1][key].length - 1).each do |ii|
            if catalog['LINES'][1][key][ii]['Voltage(kV)'] == '0.416'
              if catalog['LINES'][1][key][ii]['Line geometry'][0]['phase'] != 'N'
                wire = catalog['LINES'][1][key][ii]['Line geometry'][0]['wire']
              else
                wire = catalog['LINES'][1][key][ii]['Line geometry'][1]['wire']
              end
              jj = 0
              jj += 1 while catalog['WIRES']['WIRES CATALOG'][jj]['nameclass'] != wire
              current = catalog['WIRES']['WIRES CATALOG'][jj]['ampacity (A)'].to_i
              if catalog['LINES'][1][key][ii]['Nphases'].to_i == 3
                if ((current * (catalog['LINES'][1][key][ii]['Voltage(kV)']).to_f) * (3**0.5)) > limit_lines[:three_phase]
                  limit_lines[:three_phase] = ((current * (catalog['LINES'][1][key][ii]['Voltage(kV)']).to_f) * (3**0.5)).round(2)
                end
              else
                if (current * (catalog['LINES'][1][key][ii]['Voltage(kV)']).to_f) > limit_lines[:single_phase]
                  limit_lines[:single_phase] = (current * (catalog['LINES'][1][key][ii]['Voltage(kV)']).to_f).round(2)
                end
              end
            end
          end
        end
        # evaluating all the distribution transformers included in the extended catalog and finding 3-phase and single-phase
        # distr. transformers with the highest capacity
        (0..catalog['SUBSTATIONS AND DISTRIBUTION TRANSFORMERS'].length - 1).each do |k, v|
          catalog['SUBSTATIONS AND DISTRIBUTION TRANSFORMERS'][k].each do |key, value|
            if catalog['SUBSTATIONS AND DISTRIBUTION TRANSFORMERS'][k][key][0]['Voltage level'] == 'MV-LV'
              (0..catalog['SUBSTATIONS AND DISTRIBUTION TRANSFORMERS'][k][key].length - 1).each do |i|
                if catalog['SUBSTATIONS AND DISTRIBUTION TRANSFORMERS'][k][key][i]['Nphases'] == '3'
                  if (catalog['SUBSTATIONS AND DISTRIBUTION TRANSFORMERS'][k][key][i]['Guaranteed Power(kVA)'].to_i) > limit_trafo[:three_phase]
                    limit_trafo[:three_phase] = catalog['SUBSTATIONS AND DISTRIBUTION TRANSFORMERS'][k][key][i]['Guaranteed Power(kVA)'].to_i
                  end
                else
                  if (catalog['SUBSTATIONS AND DISTRIBUTION TRANSFORMERS'][k][key][i]['Guaranteed Power(kVA)'].to_i) > limit_trafo[:single_phase]
                    limit_trafo[:single_phase] = catalog['SUBSTATIONS AND DISTRIBUTION TRANSFORMERS'][k][key][i]['Guaranteed Power(kVA)'].to_i
                  end
                end
              end
            end
          end
        end
        trafo_margin = catalog['OTHERS']['Margin of design of new facilities LV (100.0 = designs with double so that 50% is left over)'].to_i
        limit_trafo[:single_phase] = limit_trafo[:single_phase] / (1 + (trafo_margin / 100))
        limit_trafo[:three_phase] = limit_trafo[:three_phase] / (1 + (trafo_margin / 100))
        # setting as the limit for single-phase and 3-phase the component with the lowest capacity
        if limit_trafo[:three_phase] < limit_lines[:three_phase]
          limit[:three_phase] = limit_trafo[:three_phase]
        else
          limit[:three_phase] = limit_lines[:three_phase]
        end
        if limit_trafo[:single_phase] < limit_lines[:single_phase]
          limit[:single_phase] = limit_trafo[:single_phase]
        else
          limit[:single_phase] = limit_lines[:single_phase]
        end
        return limit
      end

      ##
      # Create the files that are required as input in RNM-US.
      # (e.g. streetmapAS.txt, customers.txt, customers_ext.txt, customers_profiles_p.txt, customers_profiles_q.txt,
      # customers_profiles_p_ext.txt, customers_profiles_q_ext.txt,substation_location.txt, generators.txt,
      # generator_profiles_p.txt, generator_profiles_q.txt, generator_profiles_p_ext.txt, generator_profiles_q_ext.txt,
      # ficheros_entrada.txt, ficheros_entrada_inc.txt, udcons.csv)
      ##
      def create
        # the GEOjson file is loaded and a method is called to extract the required information regarding the street, building and substation location
        street_coordinates, customers_coordinates, coordinates_buildings, tot_buildings, building_ids, substation_location, only_lv_consumers, max_num_lv_nodes, utm_zone = URBANopt::RNM::GeojsonInput.new.coordinates_feature_hash(@feature_file, @scenario_features)
        # puts("BUILDING IDS: #{building_ids}")
        # define the LV/MV limit imposed by the components of the catalog: distr.transformers and power lines and exporting the utm_zone to the catalog
        lv_limit = catalog_limits
        # verifying if running RNM-US with REopt option

        if @reopt
          if !File.join(@run_dir, 'feature_optimization').nil?
            scenario_report_path = File.join(@run_dir, 'feature_optimization')
            # creating a class prosumers with all the info for all the DER and consumption for each building
            prosumers = URBANopt::RNM::Prosumers.new(@reopt, only_lv_consumers, max_num_lv_nodes, @average_building_peak_catalog_path, lv_limit) # passing these 2 conditions to see what option did the user
          else
            raise 'scenario report is not found'
          end

        else
          if !File.join(@run_dir, 'scenario_report').nil?
            scenario_report_path = File.join(@run_dir, 'default_scenario_report')
            # creating a class consumers with all the info about the consumption for each building
            consumers = URBANopt::RNM::Consumers.new(@reopt, only_lv_consumers, max_num_lv_nodes, @average_building_peak_catalog_path, lv_limit) # passing these 2 conditions to see what option did the user applied
          else
            raise 'scenario_report is not found'
          end
        end
        file_csv = []
        file_json = []
        # finding the 2 most extreme hours of the year (maximum net demand and maximum net generation) the distribution network is planned
        hours = URBANopt::RNM::ReportScenario.new(@reopt)
        # hours_commercial = URBANopt::RNM::ReportScenario.new(@reopt)
        (0..tot_buildings - 1).each do |j|
          if @reopt
            file_csv[j] = File.join(@run_dir, (building_ids[j]).to_s, 'feature_reports', 'feature_optimization.csv')

            # check that reopt json file exists (feature optimization only)
            if !File.exist?(File.join(@run_dir, (building_ids[j]).to_s, 'feature_reports', 'feature_optimization.json'))
              msg = 'REopt feature_optimization.json file not found. To use REopt results in the RNM analysis,' \
              'first post-process the project with the --reopt-feature flag.'
              raise msg
            end

            file_json[j] = JSON.parse(File.read(File.join(@run_dir, (building_ids[j]).to_s, 'feature_reports', 'feature_optimization.json')))
            hours.aggregate_consumption(file_csv[j], file_json[j], j)
          else

            file_csv[j] = File.join(@run_dir, (building_ids[j]).to_s, 'feature_reports', 'default_feature_report.csv')
            file_json[j] = JSON.parse(File.read(File.join(@run_dir, (building_ids[j]).to_s, 'feature_reports', 'default_feature_report.json')))

            hours.aggregate_consumption(file_csv[j], file_json[j], j)
          end
        end
        hours.scenario_report_results

        # iterating over each building to define each consumer/prosumer
        (0..tot_buildings - 1).each do |j| # (0..20).each do |j|
          # use building_ids lookup to get name of results directory
          # reports will be in 'feature_reports' directory
          if @reopt
            # file_path = File.join(@run_dir, "#{building_ids[j]}", 'feature_reports', 'feature_optimization')
            # prosumers.prosumer_files_load(file_path[j] + ".csv", File.read(file_path + ".json"), customers_coordinates[j], coordinates_buildings[j], hours)
            prosumers.prosumer_files_load(file_csv[j], file_json[j], customers_coordinates[j], coordinates_buildings[j], hours)
          else
            # file_path = File.join(@run_dir, "#{building_ids[j]}", '014_default_feature_reports', 'default_feature_reports')
            consumers.customer_files_load(file_csv[j], file_json[j], customers_coordinates[j], coordinates_buildings[j], hours)
          end
        end
        rnm_us_catalog = URBANopt::RNM::RnmUsCatalogConversion.new(@extended_catalog_path, @run_dir, @rnm_dirname)
        rnm_us_catalog.processing_data(utm_zone)
        # call and create the opendss_catalog class if the user wants to convert the extended catalog into OpenDSS catalog
        if @opendss_catalog
          @opendss_catalog = URBANopt::RNM::ConversionToOpendssCatalog.new(@extended_catalog_path)
          # create catalog and save to specified path
          @opendss_catalog.create_catalog(File.join(@run_dir, 'opendss_catalog.json'))
        end
        # creating all the inputs files required by the RNM-US model in the folder Inputs in the RNM folder
        File.open(File.join(@run_dir, @rnm_dirname, 'streetmapAS.txt'), 'w+') do |f|
          f.puts(street_coordinates.map { |x| x.join(';') })
        end
        ficheros_entrada = []
        if substation_location != 'nil'
          File.open(File.join(@run_dir, @rnm_dirname, 'primary_substations.txt'), 'w+') do |f|
            f.puts(substation_location.map { |x| x.join(';') })
          end
          ficheros_entrada = []
          ficheros_entrada.push('CSubestacionDistribucionGreenfield;primary_substations.txt')
          ficheros_entrada.push('CPuntoCallejero;streetmapAS.txt')
          ficheros_entrada.push('END')
          File.open(File.join(@run_dir, @rnm_dirname, 'ficheros_entrada.txt'), 'w+') do |f|
            f.puts(ficheros_entrada)
          end
        else
          puts('substation location automatically chosen by RNM-US model')
          ficheros_entrada.push('CPuntoCallejero;streetmapAS.txt')
          ficheros_entrada.push('END')
          File.open(File.join(@run_dir, @rnm_dirname, 'ficheros_entrada.txt'), 'w+') do |f|
            f.puts(ficheros_entrada)
          end
        end
        ficheros_entrada_inc = []
        if @reopt
          File.open(File.join(@run_dir, @rnm_dirname, 'customers.txt'), 'w+') do |f|
            f.puts(prosumers.customers.map { |x| x.join(';') })
          end
          File.open(File.join(@run_dir, @rnm_dirname, 'customers_ext.txt'), 'w+') do |g|
            g.puts(prosumers.customers_ext.map { |w| w.join(';') })
          end
          File.open(File.join(@run_dir, @rnm_dirname, 'cust_profile_p.txt'), 'w+') do |g|
            g.puts(prosumers.profile_customer_p.map { |w| w.join(';') })
          end
          File.open(File.join(@run_dir, @rnm_dirname, 'cust_profile_q.txt'), 'w+') do |g|
            g.puts(prosumers.profile_customer_q.map { |w| w.join(';') })
          end
          # CSV.open(File.join(@run_dir, @rnm_dirname, "cust_profile_q_extendido.csv"), "w") do |csv|
          #             csv << [prosumers.profile_customer_q_ext]
          #         end
          File.open(File.join(@run_dir, @rnm_dirname, 'cust_profile_q_extendido.txt'), 'w+') do |g|
            g.puts(prosumers.profile_customer_q_ext.map { |w| w.join(';') })
          end
          File.open(File.join(@run_dir, @rnm_dirname, 'cust_profile_p_extendido.txt'), 'w+') do |g|
            g.puts(prosumers.profile_customer_p_ext.map { |w| w.join(';') })
          end
          File.open(File.join(@run_dir, @rnm_dirname, 'generators.txt'), 'w+') do |g|
            g.puts(prosumers.dg.map { |w| w.join(';') })
          end
          # creating profiles txt files
          File.open(File.join(@run_dir, @rnm_dirname, 'gen_profile_p.txt'), 'w+') do |g|
            g.puts(prosumers.dg_profile_p.map { |w| w.join(';') })
          end
          File.open(File.join(@run_dir, @rnm_dirname, 'gen_profile_q.txt'), 'w+') do |g|
            g.puts(prosumers.dg_profile_q.map { |w| w.join(';') })
          end
          File.open(File.join(@run_dir, @rnm_dirname, 'gen_profile_q_extendido.txt'), 'w+') do |g|
            g.puts(prosumers.profile_dg_q_extended.map { |w| w.join(';') })
          end
          File.open(File.join(@run_dir, @rnm_dirname, 'gen_profile_p_extendido.txt'), 'w+') do |g|
            g.puts(prosumers.profile_dg_p_extended.map { |w| w.join(';') })
          end
          ficheros_entrada_inc.push('CClienteGreenfield;customers_ext.txt;cust_profile_p.txt;cust_profile_q.txt;cust_profile_p_extendido.txt;cust_profile_q_extendido.txt')
          ficheros_entrada_inc.push('CGeneradorGreenfield;generators.txt;gen_profile_p.txt;gen_profile_q.txt;gen_profile_p_extendido.txt;gen_profile_q_extendido.txt')
          ficheros_entrada_inc.push('END')
          File.open(File.join(@run_dir, @rnm_dirname, 'ficheros_entrada_inc.txt'), 'w+') do |g|
            g.puts(ficheros_entrada_inc)
          end
        else
          File.open(File.join(@run_dir, @rnm_dirname, 'customers.txt'), 'w+') do |f|
            f.puts(consumers.customers.map { |x| x.join(';') })
          end
          File.open(File.join(@run_dir, @rnm_dirname, 'customers_ext.txt'), 'w+') do |g|
            g.puts(consumers.customers_ext.map { |w| w.join(';') })
          end
          File.open(File.join(@run_dir, @rnm_dirname, 'cust_profile_p.txt'), 'w+') do |g|
            g.puts(consumers.profile_customer_p.map { |w| w.join(';') })
          end
          File.open(File.join(@run_dir, @rnm_dirname, 'cust_profile_q.txt'), 'w+') do |g|
            g.puts(consumers.profile_customer_q.map { |w| w.join(';') })
          end
          File.open(File.join(@run_dir, @rnm_dirname, 'cust_profile_q_extendido.txt'), 'w+') do |g|
            g.puts(consumers.profile_customer_q_ext.map { |w| w.join(';') })
          end
          File.open(File.join(@run_dir, @rnm_dirname, 'cust_profile_p_extendido.txt'), 'w+') do |g|
            g.puts(consumers.profile_customer_p_ext.map { |w| w.join(';') })
          end
          ficheros_entrada_inc.push('CClienteGreenfield;customers_ext.txt;cust_profile_p.txt;cust_profile_q.txt;cust_profile_p_extendido.txt;cust_profile_q_extendido.txt')
          ficheros_entrada_inc.push('END')
          File.open(File.join(@run_dir, @rnm_dirname, 'ficheros_entrada_inc.txt'), 'w+') do |g|
            g.puts(ficheros_entrada_inc)
          end
        end
      end

      ##
      # Delete the RNM-US input files directory
      ##
      def delete
        if Dir.exist?(File.join(@run_dir, @rnm_dirname))
          FileUtils.rm_rf(File.join(@run_dir, @rnm_dirname))
        end
      end
    end
  end
end

# *********************************************************************************
# URBANopt™, Copyright © Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-rnm-us-gem/blob/develop/LICENSE.md
# *********************************************************************************

require 'urbanopt/rnm/logger'

module URBANopt
  module RNM
    class PostProcessor
      ##
      # Initialize Post-Processor
      ##
      # [parameters:]
      # * +results+ - _Hash_ - Hash of RNM-US results returned from the API
      # * +scenario+ - _String_ - Path to scenario_dir
      def initialize(results, scenario_dir, feature_file, reopt: false)
        @results = results
        @scenario_dir = scenario_dir
        @results_dir = File.join(@scenario_dir, 'rnm-us', 'results')
        @report_filename = 'scenario_report_rnm.json'
        @geojson_filename = 'feature_file_rnm.json'
        @feature_file = feature_file
        @reopt = reopt
      end

      ##
      # Post Process report and feature file
      ##
      def post_process
        generate_report
        generate_feature_file
        puts "RNM results were added to scenario report and feature file. New files can be found in #{@results_dir}"
      end

      ##
      # Generate Scenario report
      ##
      def generate_report
        # calculate rnm statistics
        rnm_stats = calculate_stats

        # get scenario
        scenario = get_scenario

        # merge stats with scenario report (before feature_reports section)

        scenario['scenario_report']['rnm_results'] = rnm_stats

        # save back to scenario directory as scenario_report_rnm.json
        File.open(File.join(@scenario_dir, @report_filename), 'w') do |f|
          f.write(JSON.pretty_generate(scenario))
        end
      end

      ##
      # Load Scenario Report
      ##
      def get_scenario
        if @reopt
          # get reopt scenario report
          return JSON.parse(File.read(File.join(@scenario_dir, 'feature_optimization.json')))
        else
          # get default scenario report
          return JSON.parse(File.read(File.join(@scenario_dir, 'default_scenario_report.json')))
        end
      end

      ##
      # Generate new GeoJSON file
      ##
      def generate_feature_file
        # get results GeoJSON file and read in
        results = JSON.parse(File.read(File.join(@results_dir, 'GeoJSON', 'Distribution_system.json')))

        # merge the two files
        results['features'].each do |feature|
          @feature_file['features'].append(feature)
        end

        # save back to scenario directory as features_and_rnm.json
        File.open(File.join(@scenario_dir, @geojson_filename), 'w') do |f|
          f.write(JSON.pretty_generate(@feature_file))
        end
      end

      ##
      # Calculate report statistics from raw results
      ##
      def calculate_stats
        # calculate statistics and append to scenario report
        stats = {}
        # demand generation planning
        stats['demand_generation_planning'] = []
        @results['Demand/generation and number of consumers/distributed generators'].each do |item|
          rec = {}
          puts "ITEM VOLTAGE LEVEL: #{item['Voltage level']}, item type: #{item['Type'].strip}"
          case item['Voltage level']
          when 'LV'
            rec['type'] = "Low Voltage (LV) #{item['Type'].strip}"
          when 'MV'
            rec['type'] = "Medium Voltage (MV) #{item['Type'].strip}"
          else
            rec['type'] = item['Voltage level'] + item['Type'].strip
          end
          if item['Type'].strip == 'Consumers'
            # consumers
            rec['peak_demand_kw'] = item['Peak demand/generation (kW)']
          elsif item['Type'].include? 'generators'
            # generators
            rec['max_generation_kw'] = item['Peak demand/generation (kW)']
          else
            rec['peak_demand_generation_kw'] = item['Peak demand/generation (kW)']
          end
          rec['number_of_nodes_in_network'] = item['Number']
          stats['demand_generation_planning'] << rec
        end

        # lines LV and MV
        stats['electrical_lines_length'] = {}
        km_to_mi = 0.621371
        @results['Length of overhead and underground electrical lines'].each do |item|
          case item['Voltage level']
          when 'Lines LV'
            stats['electrical_lines_length']['low_voltage'] = {}
            stats['electrical_lines_length']['low_voltage']['overhead_mi'] = (item['Overhead (km)'] * km_to_mi).round(4)
            stats['electrical_lines_length']['low_voltage']['underground_mi'] = (item['Underground (km)'] * km_to_mi).round(4)
          when 'Lines MV'
            stats['electrical_lines_length']['medium_voltage'] = {}
            stats['electrical_lines_length']['medium_voltage']['overhead_mi'] = (item['Overhead (km)'] * km_to_mi).round(4)
            stats['electrical_lines_length']['medium_voltage']['underground_mi'] = (item['Underground (km)'] * km_to_mi).round(4)
          end
        end
        transformer_capacity = 0
        @results['Substations and distribution transformers'].each do |item|
          transformer_capacity += item['Size (kVA)'] * item['Number']
        end
        stats['distribution_transformers_capacity_kva'] = transformer_capacity

        # costs
        stats['costs'] = {}
        stats['costs']['investment'] = {}
        stats['costs']['yearly_maintenance'] = {}
        @results['Summary'].each do |item|
          case item['Level']
          when 'LV'
            stats['costs']['investment']['low_voltage_network'] = item['Investment cost']
            stats['costs']['yearly_maintenance']['low_voltage_network'] = item['Preventive maintenance (yearly)']
          when 'MV'
            stats['costs']['investment']['medium_voltage_network'] = item['Investment cost']
            stats['costs']['yearly_maintenance']['medium_voltage_network'] = item['Preventive maintenance (yearly)']
          when 'Dist.Transf.'
            stats['costs']['investment']['distribution_transformers'] = item['Investment cost']
            stats['costs']['yearly_maintenance']['distribution_transformers'] = item['Preventive maintenance (yearly)']
          when 'HV/MV Subest.'
            stats['costs']['investment']['primary_substations'] = item['Investment cost']
            stats['costs']['yearly_maintenance']['primary_substations'] = item['Preventive maintenance (yearly)']
          end
        end
        # cost totals
        inv_tot = 0
        stats['costs']['investment'].each do |key, val|
          inv_tot += val
        end
        stats['costs']['investment']['total'] = inv_tot
        maint_tot = 0
        stats['costs']['yearly_maintenance'].each do |key, val|
          maint_tot += val
        end
        stats['costs']['yearly_maintenance']['total'] = maint_tot

        # reliability indexes
        stats['reliability_indexes'] = {}
        # sum of interruptions duration / num customers.  6 would be too high
        stats['reliability_indexes']['SAIDI'] = @results['Reliability indexes'][0]['ASIDI']
        # num interruptions / num customers.  should be < 1
        stats['reliability_indexes']['SAIFI'] = @results['Reliability indexes'][0]['ASIFI']

        return stats
      end
    end
  end
end

# *********************************************************************************
# URBANopt (tm), Copyright (c) 2019-2021, Alliance for Sustainable Energy, LLC, and other
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
# originally provided by Alliance as “URBANopt”. Except to comply with the foregoing,
# the term “URBANopt”, or any confusingly similar designation may not be used to
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

require 'urbanopt/rnm/logger'
# require 'urbanopt/reporting/default_reports'

module URBANopt
  module RNM
    class PostProcessor
      ##
      # Initialize Post-Processor
      ##
      # [parameters:]
      # * +results+ - _Hash_ - Hash of RNM-US results returned from the API
      # * +scenario+ - _String_ - Path to scenario_dir
      def initialize(results, scenario_dir)
        @results = results
        @scenario_dir = scenario_dir
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
        @results['Length of overhead and underground electrical lines'].each do |item|
          case item['Voltage level']
     when 'Lines LV'
       stats['electrical_lines_length']['low_voltage'] = {}
       stats['electrical_lines_length']['low_voltage']['overhead_km'] = item['Overhead (km)']
       stats['electrical_lines_length']['low_voltage']['underground_km'] = item['Underground (km)']
          when 'Lines MV'
            stats['electrical_lines_length']['medium_voltage'] = {}
            stats['electrical_lines_length']['medium_voltage']['overhead_km'] = item['Overhead (km)']
            stats['electrical_lines_length']['medium_voltage']['underground_km'] = item['Underground (km)']
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
        stats['costs']['maintenance_yr'] = {}
        @results['Summary'].each do |item|
          case item['Level']
     when 'LV'
       stats['costs']['investment']['low_voltage_network'] = item['Investment cost']
       stats['costs']['maintenance_yr']['low_voltage_network'] = item['Preventive maintenance (yearly)']
          when 'MV'
            stats['costs']['investment']['medium_voltage_network'] = item['Investment cost']
            stats['costs']['maintenance_yr']['medium_voltage_network'] = item['Preventive maintenance (yearly)']
          when 'Dist.Transf.'
            stats['costs']['investment']['distribution_transformers'] = item['Investment cost']
            stats['costs']['maintenance_yr']['distribution_transformers'] = item['Preventive maintenance (yearly)']
          when 'HV/MV Subest.'
            stats['costs']['investment']['primary_substations'] = item['Investment cost']
            stats['costs']['maintenance_yr']['primary_substations'] = item['Preventive maintenance (yearly)']
          end
        end
        # cost totals
        inv_tot = 0
        stats['costs']['investment'].each do |key, val|
          inv_tot += val
        end
        stats['costs']['investment']['total'] = inv_tot
        maint_tot = 0
        stats['costs']['maintenance_yr'].each do |key, val|
          maint_tot += val
        end
        stats['costs']['maintenance_yr']['total'] = maint_tot

        # reliability indexes
        stats['reliability_indexes'] = {}
        # sum of interruptions duration / num customers.  6 would be too high
        stats['reliability_indexes']['SAIDI'] = @results['Reliability indexes'][0]['ASIDI']
        # num interruptions / num customers.  should be < 1
        stats['reliability_indexes']['SAIFI'] = @results['Reliability indexes'][0]['ASIFI']

        return stats
      end

      ##
      # Save results back
      ##
      def save
        # TODO: save back to report
        # open file and read in
        # append
        # save back
      end
    end
  end
end

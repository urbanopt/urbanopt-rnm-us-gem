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

require 'json'
require 'csv'
module URBANopt
  module RNM
    # creating a class that creates the consumers input required by the RNM-US model,
    # according to their geographic location, energy consumption and peak demand, and power consumption profiles
    class Prosumers
      attr_accessor :customers, :customers_ext, :profile_customer_p, :profile_customer_q, :profile_customer_p_ext, :profile_customer_q_ext, :dg, :dg_profile_p, :dg_profile_q, :profile_dg_p_extended, :profile_dg_q_extended, :power_factor

      # initializing all the attributes to build the inputs files required by the RNM-US model
      def initialize(reopt, only_lv_consumers = false, max_num_lv_nodes, average_building_peak_catalog_path, lv_limit)
        @reopt = reopt
        @average_building_peak_catalog_path = average_building_peak_catalog_path
        @only_lv_consumers = only_lv_consumers
        @max_num_lv_nodes = max_num_lv_nodes
        @customers = []
        @customers_ext = []
        @profile_customer_p = []
        @profile_customer_q = []
        @profile_customer_p_ext = []
        @profile_customer_q_ext = []
        @dg = []
        @dg_profile_p = []
        @dg_profile_q = []
        @profile_dg_p_extended = []
        @profile_dg_q_extended = []
        @power_factor = power_factor
        @lv_limit = lv_limit
      end
      # creating a method to process each building electricity consumption
      # the method receives as argument the required data obtined from each feature csv and json urbanopt output files
      # and returns the customer_ext array for each feature, with the required customer data needed for RNM-US
      # and the profiles consumers files

      # method defined for the case of a single node where both battery, DG and consumers are placed
      # evaluation of the peak power in each node to define the type of connection (e.g. voltage level and n phases)
      def construct_prosumer_general(profiles, profiles_planning, single_values, building_map, area, height, users, der_capacity)
        id = building_map[3]
        id_dg = "#{building_map[3]}_DG"
        id_batt = "#{building_map[3]}_battery"
        building_map.pop # deleting the last_element of the list which represents the id
        peak_app_power_node = 0
        # defining the max peak in the hour with consumption max peak
        # in the hour with generation max peak
        # in the hour with storage max peak

        for i in 0..profiles_planning[:planning_profile_cust_active].length-1
          hourly_app_power = ((profiles_planning[:planning_profile_cust_active][i] + profiles_planning[:planning_profile_storage_active][i] - profiles_planning[:planning_profile_dg_active][i])/@power_factor).abs
          if hourly_app_power > peak_app_power_node
            peak_app_power_node = hourly_app_power
          end
        end
        # creating the customer text files (treating also the battery as a consumer) & the DG text file
        if @medium_voltage
          voltage_default = 12.47
          phases = 3
        else
          voltage_default, phases = voltage_values(peak_app_power_node / 0.9) # margin to consider 0.9 for safety reasons
        end
        @customers.push([building_map, id, voltage_default, single_values[:peak_active_power_cons], single_values[:peak_reactive_power_cons], phases])
        @customers_ext.push([building_map, id, voltage_default, single_values[:peak_active_power_cons], single_values[:peak_reactive_power_cons], phases, area, height, (single_values[:energy]).round(2), single_values[:peak_active_power_cons], single_values[:peak_reactive_power_cons], users])
        @profile_customer_q.push([id, 48, profiles_planning[:planning_profile_cust_reactive]])
        @profile_customer_p.push([id, 48, profiles_planning[:planning_profile_cust_active]])
        @profile_customer_p_ext.push([id, 8760, profiles[:yearly_profile_cust_active]])
        @profile_customer_q_ext.push([id, 8760, profiles[:yearly_profile_cust_reactive]])
        
        if der_capacity[:storage] != nil && der_capacity[:storage] > 0
          @customers.push([building_map, id_batt, voltage_default, single_values[:peak_active_power_storage],single_values[:peak_reactive_power_storage], phases])
          @customers_ext.push([building_map, id_batt, voltage_default, single_values[:peak_active_power_storage], single_values[:peak_reactive_power_storage], phases, area, height, (single_values[:energy]).round(2), single_values[:peak_active_power_storage], single_values[:peak_reactive_power_storage], users])
          @profile_customer_q.push([id_batt, 48, profiles_planning[:planning_profile_storage_reactive]])
          @profile_customer_p.push([id_batt, 48, profiles_planning[:planning_profile_storage_active]])
          @profile_customer_p_ext.push([id_batt, 8760, profiles[:yearly_profile_storage_active]])
          @profile_customer_q_ext.push([id_batt, 8760, profiles[:yearly_profile_storage_reactive]])
        end
        @dg.push([building_map, id_dg, voltage_default, der_capacity[:dg], single_values[:peak_active_power_dg].round(2), single_values[:peak_reactive_power_dg].round(2), phases])
        @dg_profile_p.push([id_dg, 48, profiles_planning[:planning_profile_dg_active]])
        @dg_profile_q.push([id_dg, 48, profiles_planning[:planning_profile_dg_reactive]])
        @profile_dg_p_extended.push([id_dg, 8760, profiles[:yearly_profile_dg_active]])
        @profile_dg_q_extended.push([id_dg, 8760, profiles[:yearly_profile_dg_reactive]])
      end

      # creating a method to process each building electricity consumption
      # the method receives as argument the required data obtined from each feature csv and json urbanopt output files
      # and returns the customer_ext array for each feature, with the required customer data needed for RNM-US
      # and the profiles consumers files

      # this method is called only if the user sets the option of "only LV nodes" to true
      # defining a certain numb of nodes for each building and distributing the peak power values equally
      # among the nodes of each building
      def construct_prosumer_lv(nodes_per_bldg = 0, profiles, profiles_planning, single_values, building_map, building_nodes, area, height, users, der_capacity)
        # the default variables are defined (i.e. type and rurality type)
        planning_profile_node_active = []
        planning_profile_node_reactive = []
        yearly_profile_node_active = []
        yearly_profile_node_reactive = []
        closest_node = building_map[3].split('_')[1].to_i # refers to the closest node of the building in consideration to the street
        node = closest_node
        cont = 1
        cont_reverse = 1
        nodes_consumers = nodes_per_bldg - 1
        
        for i in 1..nodes_per_bldg
          coordinates = building_map
          node = closest_node + cont # to set the new nodes with enough distance among each others
          node_reverse = closest_node - cont_reverse
          if i > 1 && node <= building_nodes.length - 2
            coordinates = building_nodes[node] # take the closest building node index to the street and pass the nodes after it
            cont += 1
          elsif i > 1 
            coordinates = building_nodes[node_reverse]
            cont_reverse += 1
          end 
          # this condition is used to firstly place the building consumption nodes and then the last node
          # to be placed is the one referred to DG and battery for the building
          if i < nodes_per_bldg # considering the consumers nodes
            id = coordinates[3]
            coordinates.pop
            peak_active_power_cons = (single_values[:peak_active_power_cons] / nodes_consumers).round(2)
            peak_reactive_power_cons = (single_values[:peak_reactive_power_cons] / nodes_consumers).round(2)
            voltage_default, phases = voltage_values(peak_active_power_cons / @power_factor)
            for k in 0..profiles_planning[:planning_profile_cust_active].length - 1
                planning_profile_node_active[k] = (profiles_planning[:planning_profile_cust_active][k] / nodes_consumers).round(2) 
                planning_profile_node_reactive[k] = (profiles_planning[:planning_profile_cust_reactive][k] / nodes_consumers).round(2) 
            end
            for k in 0..profiles[:yearly_profile_cust_active].length - 1
              yearly_profile_node_active[k] = (profiles[:yearly_profile_cust_active][k] / nodes_consumers).round(2) 
              yearly_profile_node_reactive[k] = (profiles[:yearly_profile_cust_reactive][k] / nodes_consumers).round(2)
            end
            @customers.push([coordinates, id, voltage_default, peak_active_power_cons, peak_reactive_power_cons, phases])
            @customers_ext.push([coordinates, id, voltage_default, peak_active_power_cons, peak_reactive_power_cons, phases, area, height, (single_values[:energy] / nodes_consumers).round(2), peak_active_power_cons, peak_reactive_power_cons, users])
            @profile_customer_q.push([id, 48, planning_profile_node_reactive])
            @profile_customer_p.push([id, 48, planning_profile_node_active])
            @profile_customer_p_ext.push([id, 8760, yearly_profile_node_active])
            @profile_customer_q_ext.push([id, 8760, yearly_profile_node_reactive])
          else
            # considering the DG and battery
            voltage_default, phases = voltage_values(der_capacity[:dg]) #assuming that the pv capacity is always higher than battery capacity
            id_dg = "#{coordinates[3]}_DG"
            id_batt = "#{coordinates[3]}_battery"
            coordinates.pop
            @dg.push([coordinates, id_dg, voltage_default, der_capacity[:dg], single_values[:peak_active_power_dg].round(2), single_values[:peak_reactive_power_dg].round(2), phases])
            @dg_profile_p.push([id_dg, 48, profiles_planning[:planning_profile_dg_active]])
            @dg_profile_q.push([id_dg, 48, profiles_planning[:planning_profile_dg_reactive]])
            @profile_dg_p_extended.push([id_dg, 8760, profiles[:yearly_profile_dg_active]])
            @profile_dg_q_extended.push([id_dg, 8760, profiles[:yearly_profile_dg_reactive]])
            if der_capacity[:storage] != nil && der_capacity[:storage] > 0
              @customers.push([coordinates, id_batt, voltage_default, single_values[:peak_active_power_storage], single_values[:peak_reactive_power_storage], phases])
              @customers_ext.push([coordinates, id_batt, voltage_default, single_values[:peak_active_power_storage], single_values[:peak_reactive_power_storage], phases, area, height, (single_values[:energy]).round(2), single_values[:peak_active_power_storage], single_values[:peak_reactive_power_storage], users])
              @profile_customer_q.push([id_batt, 48, profiles_planning[:planning_profile_storage_reactive]])
              @profile_customer_p.push([id_batt, 48, profiles_planning[:planning_profile_storage_active]])
              @profile_customer_p_ext.push([id_batt, 8760, profiles[:yearly_profile_storage_active]])
              @profile_customer_q_ext.push([id_batt, 8760, profiles[:yearly_profile_storage_reactive]])
            end
          end
        end
      end

      # creating a function that for each  node defines the connection (e.g LV, MV, single-phase, 3-phase)
      # according to the catalog limits previously calculated
      def voltage_values(peak_apparent_power)
        case peak_apparent_power
          when -10000..@lv_limit[:single_phase] # set by the catalog limits
            phases = 1
            voltage_default = 0.416
          when @lv_limit[:single_phase]..@lv_limit[:three_phase] # defined from the catalog (from the wires)
            phases = 3
            voltage_default = 0.416
          # MV and 3 phases untill 16 MVA defined by SMART-DS project
          when @lv_limit[:three_phase]..16000
            phases = 3
            voltage_default = 12.47
          else
            # HV and 3 phases for over 16 MVA
            phases = 3
            voltage_default = 69
        end
        return voltage_default, phases
      end

      # defining a method to calculate the total sum of DG and battery capacity for each building in the district
      def sum_dg(dg)
        capacity = Hash.new(0)
        for i in 0..dg['solar_pv'].length - 1
          capacity[:dg] += dg['solar_pv'][i]['size_kw'].to_f.round(2)
        end
        for i in 0..dg['wind'].length - 1
          capacity[:dg] += dg['wind'][i]['size_kw'].to_f.round(2)
        end
        for i in 0..dg['generator'].length - 1
          capacity[:dg] += dg['generator'][i]['size_kw'].to_f.round(2)
        end
        capacity[:storage] = dg['total_storage_kw']
        return capacity
      end

      # creating a method to define the number of nodes for each building in case the user set the option "only LV" to true.
      # this method calculates the number of nodes for each building in the project and in case the numb of nodes is higher than 4
      # than the building is considered as a single node connected in MV
      # the numb of nodes is calculated based on the average_peak_catalog which is obtained from DOE open_source data per location and per building type
      def av_peak_cons_per_building_type(feature_file)
        average_peak_by_size = []
        floor_area = []
        average_peak = 5 # defining a random value first, since now the residential buildings are not considered in the catalog
        mixed_use_av_peak = 0
        area_mixed_use = 0
        @max_num_nodes = 1 # set this value as input in GeoJSON feature file
        # defining a conservative factor which creates some margin with the number of nodes found using the av_peak catalog, with the
        # actual nodes that could be found with the current buildings peak consumptions in the project
        conservative_factor = 0.8 # considered as a reasonable assumption, but this value could be changed
        average_peak_folder = JSON.parse(File.read(@average_building_peak_catalog_path))
        for i in 0..feature_file.length - 1
          area = (feature_file[i]['floor_area']).round(2)
          building_type = feature_file[i]['building_type'] #it specifies the type of building, sometimes it is directly the sub-type
          counter = 0 # counter to find number of buildings type belonging to same "category"
          average_peak_folder.each do |building_class|
            if (building_type == building_class["building type"] ||  building_type == building_class["sub-type"])
              average_peak = (building_class['average peak demand (kW/ft2)'].to_f * area).to_f.round(4) # finding the average peak considering the floor area of the bilding under consideration
              average_peak_by_size[counter] = average_peak
              floor_area[counter] = (building_class['floor_area (ft2)'] - area).abs # minimum difference among area and area from the prototypes defined by DOE
              counter += 1
            # in this way I don t consider residential and I assume it s average_peak = 0, it is ok because we assume always 1 node per RES consumers, single-detached family houses
            end
          end
          if counter > 1
            index = floor_area.index(floor_area.min)
            average_peak = average_peak_by_size[index]
          end
          if feature_file.length > 1 # defined for Mixed_use buildings, which include more building types
            mixed_use_av_peak += average_peak
            area_mixed_use += area
          end
        end
        if feature_file.length > 1
          average_peak = mixed_use_av_peak # average peak per mixed use considering the building types which are in this building
          area = area_mixed_use
        end
        nodes_per_bldg = ((average_peak / (@lv_limit[:three_phase] * @power_factor * conservative_factor)).to_f).ceil # computing number of nodes per building
        if nodes_per_bldg > @max_num_nodes # defined as reasonable maximum
          nodes_per_bldg = 1
          @medium_voltage = true
        end
  
          nodes_per_bldg += 1 # tacking into account the extra node for distributed generation and the battery    
        return nodes_per_bldg, area
      end

      # method to order profiles consistently
      def profiles_planning_creation(profiles_planning, power, single_values, i, hours, power_factor)
        profiles_planning[:planning_profile_cust_active][i] = power["REopt:Electricity:Load:Total(kw)"].to_f
        profiles_planning[:planning_profile_storage_active][i] = power['REopt:Electricity:Grid:ToBattery(kw)'].to_f + power['REopt:ElectricityProduced:Generator:ToBattery(kw)'].to_f + power['REopt:ElectricityProduced:PV:ToBattery(kw)'].to_f + power['REopt:ElectricityProduced:Wind:ToBattery(kw)'].to_f - power['REopt:Electricity:Storage:ToLoad(kw)'].to_f - power['REopt:Electricity:Storage:ToGrid(kw)'].to_f
        profiles_planning[:planning_profile_dg_active][i] = power["REopt:ElectricityProduced:Total(kw)"].to_f
        profiles_planning[:planning_profile_cust_reactive][i] = profiles_planning[:planning_profile_cust_active][i] * Math.tan(Math.acos(power_factor))
        profiles_planning[:planning_profile_storage_reactive][i] = profiles_planning[:planning_profile_storage_active][i] * Math.tan(Math.acos(power_factor))
        profiles_planning[:planning_profile_dg_reactive][i] = profiles_planning[:planning_profile_dg_active][i] * Math.tan(Math.acos(power_factor))
        if profiles_planning[:planning_profile_cust_active][i] > single_values[:peak_active_power_cons]
          single_values[:peak_active_power_cons] = profiles_planning[:planning_profile_cust_active][i]
          single_values[:peak_reactive_power_cons] = single_values[:peak_active_power_cons] * Math.tan(Math.acos(power_factor))
        end
        if profiles_planning[:planning_profile_storage_active][i] > single_values[:peak_active_power_storage]
          single_values[:peak_active_power_storage] = profiles_planning[:planning_profile_storage_active][i]
          single_values[:peak_reactive_power_storage] = single_values[:peak_active_power_storage] * Math.tan(Math.acos(power_factor))
        end
        if profiles_planning[:planning_profile_dg_active][i] > single_values[:peak_active_power_dg]
          single_values[:peak_active_power_dg] = profiles_planning[:planning_profile_dg_active][i]
          single_values[:peak_reactive_power_dg] = single_values[:peak_active_power_dg] * (Math.tan(Math.acos(power_factor)))
        end
        return profiles_planning, single_values
      end

      # defining a method for the customers and generators files creation:
      # obtaining all the needed input from each feature_report.csv file (active & apparent power and tot energy consumed and produced)
      # and from each feature_report.json file (area, height, number of users, DG capacity)
      # the method passes as arguments the urbanopt json and csv output file for each feature and the building coordinates previously calculated
      # and the "extreme" hours used to plan the network
      def prosumer_files_load(csv_feature_report, json_feature_report, building_map, building_nodes, hour)
        # add variable to include how many timestep per hour, so the profiles become 48 * n_timestep_per_hour
        n_timestep_per_hour = json_feature_report["timesteps_per_hour"].to_i
        profiles_planning = Hash.new{|h, k| h[k] = Array.new(48*n_timestep_per_hour, 0)} # initializing each profile hash to 0 for the number of intervals considered for the planning of the network
              profiles = Hash.new{|h, k| h[k] = []}
        single_values = Hash.new(0)
        @medium_voltage = false
        hours = 24 * n_timestep_per_hour -1 # change name, maybe to intervals
        feature_type = json_feature_report['program']['building_types'][0]["building_type"]
        residential_building_types = "Single-Family Detached" # add the other types
        # finding the index where to start computing and saving the info, from the value of the "worst-case hour" for the max peak consumption of the district
        # considering num timestep per hours and the fact that each day starts from 1 am
        if residential_building_types.include? feature_type
          profile_start_max = hour.hour_index_max_res - (hour.peak_hour_max_res*n_timestep_per_hour) + 1
          profile_start_min = hour.hour_index_min_res - (hour.peak_hour_min_res*n_timestep_per_hour) + 1
        else
          profile_start_max = hour.hour_index_max_comm - (hour.peak_hour_max_comm*n_timestep_per_hour) + 1
          profile_start_min = hour.hour_index_min_comm - (hour.peak_hour_min_comm*n_timestep_per_hour) + 1
        end
        # finding the index where to start computing and saving the info, from the value of the "most extreme hours" for the max peak consumption of the district
        k = 0   # index for each hour of the year represented in the csv file
        i = hours +1 # to represent the 24 hours in case of max_net_generation day
        j = 0 # to represent the 24 hours in case of peak_demand_day
        h_cons_batt = 0
        h_dg_max = 0 # hour with max DG generation
        h_stor_max = 0 # hour with max storage absorption
        max_peak = 0
        CSV.foreach(csv_feature_report, headers: true) do |power|
          @power_factor = power["Electricity:Facility Power(kW)"].to_f/ power["Electricity:Facility Apparent Power(kVA)"].to_f 
          profiles[:yearly_profile_cust_active].push(power["REopt:Electricity:Load:Total(kw)"].to_f)
          profiles[:yearly_profile_cust_reactive].push(profiles[:yearly_profile_cust_active][k] * Math.tan(Math.acos(@power_factor))) 
          profiles[:yearly_profile_dg_active].push(power["REopt:ElectricityProduced:Total(kw)"].to_f)
          profiles[:yearly_profile_dg_reactive].push(profiles[:yearly_profile_dg_active][k] * Math.tan(Math.acos(@power_factor)))
          profiles[:yearly_profile_storage_active].push(power['REopt:Electricity:Grid:ToBattery(kw)'].to_f + power['REopt:ElectricityProduced:Generator:ToBattery(kw)'].to_f + power['REopt:ElectricityProduced:PV:ToBattery(kw)'].to_f + power['REopt:ElectricityProduced:Wind:ToBattery(kw)'].to_f - power['REopt:Electricity:Storage:ToLoad(kw)'].to_f - power['REopt:Electricity:Storage:ToGrid(kw)'].to_f)
          profiles[:yearly_profile_storage_reactive].push(profiles[:yearly_profile_storage_active][k] * Math.tan(Math.acos(@power_factor)))
          single_values[:energy] += power["REopt:Electricity:Load:Total(kw)"].to_f # calculating the yearly energy consumed by each feature
          single_values[:energy_dg] += power["REopt:ElectricityProduced:Total(kw)"].to_f
          single_values[:energy_storage] += power['REopt:Electricity:Grid:ToBattery(kw)'].to_f + power['REopt:ElectricityProduced:Generator:ToBattery(kw)'].to_f + power['REopt:ElectricityProduced:PV:ToBattery(kw)'].to_f + power['REopt:ElectricityProduced:Wind:ToBattery(kw)'].to_f - power['REopt:Electricity:Storage:ToLoad(kw)'].to_f - power['REopt:Electricity:Storage:ToGrid(kw)'].to_f
          case k
          when profile_start_min..profile_start_min + (hours)
            profiles_planning, single_values = self.profiles_planning_creation(profiles_planning, power, single_values, i, hours, power_factor)
              i+=1
          when profile_start_max..profile_start_max + (hours)
            profiles_planning, single_values = self.profiles_planning_creation(profiles_planning, power, single_values, j, hours, power_factor)
            j+=1
          end
          k+=1
        end
        height = (json_feature_report['program']['maximum_roof_height_ft']).round(2)
        users = json_feature_report['program']['number_of_residential_units']
        der_capacity = self.sum_dg(json_feature_report['distributed_generation'])
        if @only_lv_consumers
          nodes_per_bldg, area = self.av_peak_cons_per_building_type(json_feature_report['program']['building_types'])
          if @max_num_nodes == 1
            self.construct_prosumer_general(profiles, profiles_planning, single_values, building_map, area, height, users, der_capacity)
          else
            self.construct_prosumer_lv(nodes_per_bldg, profiles, profiles_planning, single_values, building_map, building_nodes, area, height, users, der_capacity)
          end
        else
          area = (json_feature_report['program']['floor_area']).round(2)
          # associating 2 nodes (consumers & DG and battery in the same node) per building considering the consumer, the battery and DG
          self.construct_prosumer_general(profiles, profiles_planning, single_values, building_map, area, height, users, der_capacity)
        end 
      end
    end
  end
end

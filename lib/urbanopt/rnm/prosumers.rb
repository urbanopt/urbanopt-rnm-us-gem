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

require 'json'
require 'csv'
module URBANopt
  module RNM
	class Prosumers
		attr_accessor :customers, :customers_ext, :profile_customer_p, :profile_customer_q, :profile_customer_p_ext, :profile_customer_q_ext, :dg, :dg_profile_p, :dg_profile_q, :profile_dg_p_extended, :profile_dg_q_extended, :power_factor
		#initializing all the attributes to build the inputs files required by the RNM-US model
		def initialize(reopt, only_lv_consumers, average_building_peak_catalog_path, lv_limit)
			@reopt = reopt
			@average_building_peak_catalog_path = average_building_peak_catalog_path
			@only_lv_consumers = only_lv_consumers
			@only_lv_consumers = only_lv_consumers
			@customers= []
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
		#method defined for the case of a single node where both battery, DG and consumers are place, evaluation of the voltage level and n phases of each node connection
		def construct_prosumer_general(profiles, single_values, building_map, area, height, users, der_capacity)
			id_dg = building_map[3] + '_DG'
			id_batt = building_map[3] + '_battery'
			cons_peak = ((single_values[:peak_active_power_cons] + profiles[:peak_active_power_storage][single_values[:h_cons_max]] - profiles[:peak_active_power_dg][single_values[:h_cons_max]])/@power_factor)
			storage_peak = (single_values[:peak_active_power_storage] + profiles[:peak_active_power_cons][single_values[:h_stor_max]] - profiles[:peak_active_power_dg][single_values[:h_stor_max]])/@power_factor
			dg_peak = (single_values[:peak_active_power_dg] - profiles[:peak_active_power_storage][single_values[:h_dg_max]] - profiles[:peak_active_power_cons][single_values[:h_dg_max]])/@power_factor
			dg_peak
			if cons_peak > storage_peak && cons_peak > dg_peak
				peak_app_power_node = cons_peak
			elsif storage_peak > cons_peak && storage_peak > dg_peak
				peak_app_power_node = storage_peak
			elsif dg_peak > cons_peak && dg_peak > storage_peak
				peak_app_power_node = dg_peak
			end
			voltage_default, phases = self.voltage_values(peak_app_power_node)
			@customers.push(building_map, voltage_default, single_values[:peak_active_power_cons],single_values[:peak_reactive_power_cons], phases)
			@customers_ext.push(building_map, voltage_default, single_values[:peak_active_power_cons], single_values[:peak_reactive_power_cons], phases, area, height, (single_values[:energy]).round(2), single_values[:peak_active_power_cons], single_values[:peak_reactive_power_cons], users)
			@profile_customer_q.push(id, 48, profiles[:planning_profile_cust_reactive])
			@profile_customer_p.push(id, 48, profiles[:planning_profile_cust_active])
			@profile_customer_p_ext.push(id, 8760, profiles[:yearly_profile_cust_active])
			@profile_customer_q_ext.push(id, 8760, profiles[:yearly_profile_cust_reactive])
			if der_capacity[:storage] > 0 && der_capacity[:storage] != nil
				@customers.push(building_map.pop, id_batt, voltage_default, single_values[:peak_active_power_storage],single_values[:peak_reactive_power_storage], phases)
				@customers_ext.push(building_map.pop, id_batt, voltage_default, single_values[:peak_active_power_storage], single_values[:peak_reactive_power_storage], phases, area, height, (single_values[:energy]).round(2), single_values[:peak_active_power_storage], single_values[:peak_reactive_power_storage], users)
				@profile_customer_q.push(id_batt, 48, profiles[:planning_profile_storage_reactive])
				@profile_customer_p.push(id_batt, 48, profiles[:planning_profile_storage_active])
				@profile_customer_p_ext.push(id_batt, 8760, profiles[:yearly_profile_storage_active])
				@profile_customer_q_ext.push(id_batt, 8760, profiles[:yearly_profile_storage_reactive])
			end
			@dg.push(coordinates.pop, id_dg, voltage_default, der_capacity[:dg], single_values[:peak_active_power_dg].round(2), single_values[:peak_reactive_power_dg].round(2), phases)
			@dg_profile_p.push(id_dg, 48, profiles[:planning_profile_dg_active])
			@dg_profile_q.push(id_dg, 48, profiles[:planning_profile_dg_reactive])
			@profile_dg_p_extended.push(id_dg, 8760, profiles[:yearly_profile_dg_active])
			@profile_dg_q_extended.push(id_dg[3], 8760, profiles[:yearly_profile_dg_reactive])
		end


		# creating a method to process each building electricity consumption for the customer_ext txt file
		# the method receives as argument the required data obtined from each feature csv and json urbanopt output files
		# and returns the customer_ext array for each feature, with the required customer data needed for RNM-US
		def construct_prosumer_lv(nodes_per_bldg=0, profiles, single_values, building_map, building_nodes, area, height, users, der_capacity)
				# the default variables are defined (i.e. type and rurality type)
				planning_profile_node_active = []
				planning_profile_node_reactive = []
				yearly_profile_node_active = []
				yearly_profile_node_reactive = []
				closest_node = building_map[3].split('_')[1].to_i #refers to the node, found in the class above
				node = closest_node
				cont = 1
				cont_reverse = 1
				for i in 1..nodes_per_bldg
						coordinates = building_map
						# it refers to the number of the node considred for this building, which was defined in the bilding ID
						node = closest_node + cont #to set the new nodes with enough distance among each others
						node_reverse = closest_node - cont_reverse
						if i > 1 && node <= building_nodes.length-1
							coordinates = building_nodes[node] # take the closest building node index to the street and pass the nodes after it
							cont += 1
						elsif i > 1 
							coordinates = building_nodes[node_reverse]
							cont_reverse += 1
						end 
						if i < nodes_per_bldg #considering the consumers nodes
							id = coordinates[3]
							peak_active_power_cons = (single_values[:peak_active_power_cons] / nodes_per_bldg).round(2)
							peak_reactive_power_cons = (single_values[:peak_reactive_power_cons] / nodes_per_bldg).round(2)
							voltage_default, phases = self.voltage_values(peak_active_power_cons/@power_factor)
							for k in 0..profiles[:planning_profile_cust_active].length-1
									planning_profile_node_active[k] = (profiles[:planning_profile_cust_active][k]/nodes_per_bldg).round(2) 
									planning_profile_node_reactive[k] = (profiles[:planning_profile_cust_reactive][k]/nodes_per_bldg).round(2) 
							end
							for k in 0..profiles[:yearly_profile_cust_active].length-1
								yearly_profile_node_active[k] = (profiles[:yearly_profile_cust_active][k]/nodes_per_bldg).round(2) 
								yearly_profile_node_reactive[k] = (profiles[:yearly_profile_cust_reactive][k]/nodes_per_bldg).round(2)
							end
							@customers.push(coordinates, voltage_default, peak_active_power_cons, peak_reactive_power_cons, phases)
							@customers_ext.push(coordinates, voltage_default, peak_active_power_cons, peak_reactive_power_cons, phases, area, height, (single_values[:energy]/nodes_per_bldg).round(2), peak_active_power_cons, peak_reactive_power_cons, users)
							@profile_customer_q.push(id, 48, planning_profile_node_reactive)
							@profile_customer_p.push(id, 48, planning_profile_node_active)
							@profile_customer_p_ext.push(id, 8760, yearly_profile_node_active)
							@profile_customer_q_ext.push(id, 8760, yearly_profile_node_reactive)
							customers[n] = coordinates, voltage_default, peak_active_power_cons, peak_reactive_power_cons, phases
						else
							voltage_default, phases = self.voltage_values(der_capacity[:dg]) #assuming that the pv capacity is always higher than battery capacity
							id_dg = coordinates[3] + '_DG'
							id_batt = coordinates[3] + '_battery'
							real_coord = coordinates.pop
							@dg.push(real_coord, id_dg, voltage_default, der_capacity[:dg], single_values[:peak_active_power_dg].round(2), single_values[:peak_reactive_power_dg].round(2), phases)
							@dg_profile_p.push(id_dg, 48, profiles[:planning_profile_dg_active])
							@dg_profile_q.push(id_dg, 48, profiles[:planning_profile_dg_reactive])
							@profile_dg_p_extended.push(id_dg, 8760, profiles[:yearly_profile_dg_active])
							@profile_dg_q_extended.push(id_dg[3], 8760, profiles[:yearly_profile_dg_reactive])
							if der_capacity[:storage] > 0 && der_capacity[:storage] != nil
								@customers.push([real_coord, id_batt, voltage_default, single_values[:peak_active_power_storage],single_values[:peak_reactive_power_storage], phases])
								@customers_ext.push([real_coord, id_batt, voltage_default, single_values[:peak_active_power_storage], single_values[:peak_reactive_power_storage], phases, area, height, (single_values[:energy]).round(2), single_values[:peak_active_power_storage], single_values[:peak_reactive_power_storage], users])
								@profile_customer_q.push([id_batt, 48, profiles[:planning_profile_storage_reactive]])
								@profile_customer_p.push([id_batt, 48, profiles[:planning_profile_storage_active]])
								@profile_customer_p_ext.push([id_batt, 8760, profiles[:yearly_profile_storage_active]])
								@profile_customer_q_ext.push([id_batt, 8760, profiles[:yearly_profile_storage_reactive]])
							end
						end
				end
			end
	
			def voltage_values(peak_apparent_power)
				# defining the number of phases, voltage and simultaneity factor for each feature according to the limits defined for the SMART-DS project
				case peak_apparent_power
					# LV and 1 phase untill 50 kVA
					when -10000..@lv_limit[:single_phase] # set by the catalog limits
						phases = 1
						voltage_default = 0.416
						# LV and 3 phases untill 1 MVA
					when @lv_limit[:single_phase]..@lv_limit[:three_phase] # def from the catalog (from the wires)
						phases = 3
						voltage_default = 0.416
						# MV and 3 phases untill 16 MVA
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
	
		def sum_dg(dg)
			capacity = Hash.new(0)
			for i in 0..dg['solar_pv'].length-1
				capacity[:dg] += dg['solar_pv'][i]['size_kw'].to_f.round(2)
			end
			for i in 0..dg['wind'].length-1
				capacity[:dg] += dg['wind'][i]['size_kw'].to_f.round(2)
			end 
			for i in 0..dg['generator'].length-1
				capacity[:dg] += dg['generator'][i]['size_kw'].to_f.round(2)
			end
			capacity[:storage] = dg['total_storage_kw']
			return capacity
		end
		def av_peak_cons_per_building_type(feature_file)
			average_peak_by_size = []
			floor_area = []
			average_peak = 5 # defining a random value first, since now the residential buildings are not considered in the catalog
			mixed_use_av_peak = 0
			area_mixed_use = 0        
			conservative_factor = 0.8 #ask the user to input this value--> by creating a json file with this input
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
				if feature_file.length > 1 #defined for Mixed_use buildings, which include more building types
					mixed_use_av_peak += average_peak
					area_mixed_use += area
				end
			end
			if feature_file.length > 1
				average_peak = mixed_use_av_peak # average peak per mixed use considering the building types which are in this building
				area = area_mixed_use
			end
			nodes_per_bldg = ((average_peak / (@lv_limit[:three_phase]* @power_factor * conservative_factor)).to_f).ceil # computing number of nodes per building
			if nodes_per_bldg > 4 #defined as reasonable maximum
				nodes_per_bldg = 1
			end
			nodes_per_bldg += 1 #tacking into account the extra node for distributed generation and the battery
			return nodes_per_bldg, area
		end
		# defining a method for the customers_ext file creation: 
		# obtaining all the needed input from each feature_report.csv file (active & apparent power and tot energy consumed)
		# and from each feature_report.json file (area, height, number of users)
		# the method passes as arguments each urbanopt json and csv output file for each feature and the building coordinates previously calculated
		# and returns an array containing all the data for the creation of the customer_ext.txt file
		def prosumer_files_load(csv_feature_report, json_feature_report, building_map, building_nodes, hour)
			#magari sostituire questo con un hash per ridurre righe di codice
			# planning_profile_cust_active = []
			# planning_profile_dg_active = []
			# planning_profile_cust_reactive = []
			# planning_profile_dg_reactive = []
			# planning_profile_storage_active = []
			# planning_profile_storage_reactive = []
			# yearly_profile_cust_active = []
			# yearly_profile_cust_reactive = []
			# yearly_profile_dg_active = []
			# yearly_profile_dg_reactive = []
			# yearly_profile_storage_reactive = []
			# yearly_profile_storage_active = []
			profiles = Hash.new{|h, k| h[k] = []}
			single_values = Hash.new(0)
			# single_values[:energy] = 0
			# single_values[:energy_dg] = 0
			# single_values[:energy_storage] = 0
			# single_values[:peak_active_power_dg] = 0
			# single_values[:peak_reactive_power_dg] = 0
			# single_values[:peak_active_power_storage] = 0
			# single_values[:peak_reactive_power_storage] = 0
			# single_values[:peak_active_power_cons] = 0
			# single_values[:peak_reactive_power_cons] = 0
			#peak_cons_batt = 0
			hours = 23
			profile_start_max = hour.hour_index_max - hour.peak_hour_max #finding the index where to start computing and saving the info
			profile_start_min = hour.hour_index_min - hour.peak_hour_min
			k = 0   # index for each hour of the year represented in the csv file 
			i = 0 #to represent the 24 hours
			h_cons_batt = 0
			h_dg_max = 0 #hour with max DG generation
			h_stor_max = 0 #hour with max storage absorption
				# ora chiamero questa funzione esternamente
			content = CSV.foreach(csv_feature_report, headers: true) do |power|
				@power_factor = power["REopt:Electricity:Load:Total(kw)"].to_f/ power["Electricity:Facility Apparent Power(kVA)"].to_f
				profiles[:yearly_profile_cust_active].push(power["REopt:Electricity:Load:Total(kw)"].to_f)
				profiles[:yearly_profile_cust_reactive].push(profiles[:yearly_profile_cust_active][k] * Math.tan(Math.acos(@power_factor))) #change all this using apparent power
				profiles[:yearly_profile_dg_active].push(power["REopt:ElectricityProduced:Total(kw)"].to_f)
				profiles[:yearly_profile_dg_reactive].push(profiles[:yearly_profile_dg_active][k] * Math.tan(Math.acos(@power_factor)))
				profiles[:yearly_profile_storage_active].push(power['REopt:Electricity:Grid:ToBattery(kw)'].to_f + power['REopt:ElectricityProduced:Generator:ToBattery(kw)'].to_f + power['REopt:ElectricityProduced:PV:ToBattery(kw)'].to_f + power['REopt:ElectricityProduced:Wind:ToBattery(kw)'].to_f - power['REopt:Electricity:Storage:ToLoad(kw)'].to_f - power['REopt:Electricity:Storage:ToGrid(kw)'].to_f)
				profiles[:yearly_profile_storage_reactive].push(profiles[:yearly_profile_storage_active][k] * Math.tan(Math.acos(@power_factor)))
				single_values[:energy] += power["REopt:Electricity:Load:Total(kw)"].to_f # calculating the yearly energy consumed by each feature
				single_values[:energy_dg] += power["REopt:ElectricityProduced:Total(kw)"].to_f
				single_values[:energy_storage] += power['REopt:Electricity:Grid:ToBattery(kw)'].to_f + power['REopt:ElectricityProduced:Generator:ToBattery(kw)'].to_f + power['REopt:ElectricityProduced:PV:ToBattery(kw)'].to_f + power['REopt:ElectricityProduced:Wind:ToBattery(kw)'].to_f - power['REopt:Electricity:Storage:ToLoad(kw)'].to_f - power['REopt:Electricity:Storage:ToGrid(kw)'].to_f
				if k >= profile_start_max && k <= profile_start_max + hours || k >= profile_start_min && k <= profile_start_min + hours
					profiles[:planning_profile_cust_active].push(power["REopt:Electricity:Load:Total(kw)"].to_f)
					if profiles[:planning_profile_cust_active][i] > single_values[:peak_active_power_cons]
						single_values[:peak_active_power_cons] = profiles[:planning_profile_cust_active][i]
						single_values[:peak_reactive_power_cons] = single_values[:peak_active_power_cons] * Math.tan(Math.acos(power_factor))
						single_values[:h_cons_max] = i
					end
					profiles[:planning_profile_storage_active].push((power['REopt:Electricity:Grid:ToBattery(kw)'].to_f + power['REopt:ElectricityProduced:Generator:ToBattery(kw)'].to_f + power['REopt:ElectricityProduced:PV:ToBattery(kw)'].to_f + power['REopt:ElectricityProduced:Wind:ToBattery(kw)'].to_f - power['REopt:Electricity:Storage:ToLoad(kw)'].to_f - power['REopt:Electricity:Storage:ToGrid(kw)'].to_f))
					if profiles[:planning_profile_storage_active][i] > single_values[:peak_active_power_storage]
						single_values[:peak_active_power_storage] = profiles[:planning_profile_storage_active][i]
						single_values[:peak_reactive_power_storage] = single_values[:peak_active_power_storage] * Math.tan(Math.acos(power_factor))
						single_values[:h_stor_max] = i
					end
					profiles[:planning_profile_dg_active].push(power["REopt:ElectricityProduced:Total(kw)"].to_f)
					if profiles[:planning_profile_dg_active][i] > single_values[:peak_active_power_dg]
						single_values[:peak_active_power_dg] = profiles[:planning_profile_dg_active][i]
						single_values[:peak_reactive_power_dg] = single_values[:peak_active_power_dg] * (Math.tan(Math.acos(power_factor)))
						single_values[:h_dg_max] = i
					end
					#if profiles[:planning_profile_cust_active[i]] + planning_profile_storage_active[i] > peak_cons_batt
					#	peak_cons_batt = planning_profile_cust_active[i] + planning_profile_storage_active[i]
					#	h_cons_batt = i
					#end
					profiles[:planning_profile_cust_reactive].push(profiles[:planning_profile_cust_active][i] * Math.tan(Math.acos(power_factor)))
					profiles[:planning_profile_storage_reactive].push(profiles[:planning_profile_storage_active][i] * Math.tan(Math.acos(power_factor)))
					profiles[:planning_profile_dg_reactive].push(profiles[:planning_profile_dg_active][i] * Math.tan(Math.acos(power_factor)))
							#profile_cust_apparent[i] = power["Electricity:Facility Apparent Power(kVA)"].to_f #later this will be used
							#profile_dg_apparent[i] = power["ElectricityProduced:Facility Apparent Power(kVA)"].to_f
					i+=1
				end
				k+=1
			end 
			#parsing the required information from feature.json file
			folder =  JSON.parse(json_feature_report) 
			height = (folder['program']['maximum_roof_height_ft']).round(2)
			users = folder['program']['number_of_residential_units']
			der_capacity = self.sum_dg(folder['distributed_generation'])
			if @only_lv_consumers
				nodes_per_bldg, area = self.av_peak_cons_per_building_type(folder['program']['building_types'])
				#diventa contruct prosumer e ci passo anche dg e batt
				self.construct_prosumer_lv(nodes_per_bldg, profiles, single_values, building_map, building_nodes, area, height, users, der_capacity)
			
			else
				#associating 2 nodes (consumers & DG and battery in the same node) per building considering the consumer, the battery and DG
				self.construct_prosumer_general(profiles, single_values, building_map, area, height, users, dg_capacity, storage_capacity)
			end	
		end
    end
end
end
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
require 'geoutm'

module URBANopt
  module RNM
  	# creating a class to process each costumer consumption and coordinate (including both buildings and streets)
		class Processor
	    # defining a method to set each street nodes to a uniform distance among eachothers, valid for both streets and buildings
	    # the method is passing as arguments the harsh with each feature info from the geojson file, the latitude and longitude to be converted to UTM,
	    # the array containing the already processed nodes, the index defining the position of the lat and lon passed in this method
	    # and the index defining the reached position in the array with the processed nodes
	    # this method returns the array with the processed nodes and its index
	    def coordinates(harsh, lat, lon, coordinates, k, i)
        lat_lon = GeoUtm::LatLon.new(lat, lon)
        z = 0 #default value for surface elevation
        uniform_distance = 10 # values set as uniform distance among nodes
        utm = lat_lon.to_utm # converting latitude and longitude to UTM
        x_utm = utm.e.round(2) # UTM x-distance from the origin
        y_utm = utm.n.round(2) # UTM y-distance from the origin
        identifier = harsh['properties']['id']
        # creating streetmap nodes every 10 m for each road, considering the angle of each road
        if k != 0
            distance_y = y_utm - coordinates[i-1][1] 
            distance_x = x_utm - coordinates[i-1][0]
            distance = ((distance_x)**2 + (distance_y)**2)**(0.5)
            intervals = (distance / uniform_distance).to_i
            # creating variables for x, y for each node, with the right street inclination
            x_uniform = uniform_distance * (distance_x / distance)
            y_uniform = uniform_distance * (distance_y / distance)
            n = 1 # counter to keep track when the number of intervals for each "distnce" is reached
            # creating nodes in the coordinates array with the right street inclination and uniform distance among each others
            while n <= intervals
                id = identifier.to_s + "_#{i}"
                coordinates[i] = (coordinates[i-1][0] + x_uniform).round(2), (coordinates[i-1][1] + y_uniform ).round(2), z, id
                i += 1
                n += 1
            end
            # when the last interval of each road is reached, the last node values are given as the streets coordinates
            # imported from the street.json file
            id = identifier.to_s + "_#{i}"
            coordinates[i] = x_utm.round(2), y_utm.round(2), z, id
            i += 1
        else
                # in the 1st node of each road, the coordinates are tacken directly from the streetmap.json file
                id = identifier.to_s + "_#{i}"
                coordinates[i] = x_utm, y_utm, z, id
                i += 1
        end 
        return coordinates, i
	    end 

	    # defining a method to find the coordinates of the closest node of each building building to the closest street, to be used for the customers_ext.txt file
	    # the method receives as arguments every nodes of 1 building and the array containing all the street nodes computed before
	    # and it returns the coordinates and id of the closest node of the building to the street
	    def consumer_coordinates(building, street)
        distance = []
        min_dist = []
        # iterating the distance among each node of each street and each node of each building until the minimum distance is found
        for j in 0..building.length-1 # assessing each building node of the considered building
            for i in 0..street.length-1 # assessing each street node
                y = building[j][1]-street[i][1]
                x = building[j][0] - street[i][0]
                distance[i] = (x**2 + y**2)**(0.5) # finding the distance of each building node with each street node
            end
            min_dist[j] = distance.min() # finding the min distance for each node of the building
        end
        index = min_dist.index {|x| x == min_dist.min()} # finding the index position of the node with the closest distance to the street 
        chosen_coord = building[index] # assigning the closest node coordinates values and id to chose_coord variable
        return chosen_coord
	    end 

	    # creating a method to process each building electricity consumption for the customer_ext txt file
	    # the method receives as argument the required data obtined from each feature csv and json urbanopt output files
	    # and returns the customer_ext array for each feature, with the required customer data needed for RNM-US
	    def construct_costumer(active_power, apparent_power, energy, building_map, area, height, users)
        # the default variables are defined (i.e. type and rurality type)
        peak_active_power = active_power.max().round(2)
        peak_apparent_power = apparent_power.max().round(2)
        reactive_power = ((peak_apparent_power**2-peak_active_power**2)**(0.5)).round(2)
        # defining the number of phases, voltage and simultaneity factor for each feature according to the limits defined for the SMART-DS project
        case peak_apparent_power
          # LV and 1 phase untill 50 kVA
          when 0..50
              phases = 1
              voltage_default = 0.416
              simulteneity_factor = 0.4 # default value, used to not oversize the system
              peak_active_power_CF = peak_active_power*simulteneity_factor
              reactive_power_CF = reactive_power*simulteneity_factor
              # LV and 3 phases untill 1 MVA
          when 50..1000
              phases = 3
              voltage_default = 0.416
              simulteneity_factor = 0.4 # default value
              peak_active_power_CF = peak_active_power * simulteneity_factor
              reactive_power_CF = reactive_power * simulteneity_factor
              # MV and 3 phases untill 16 MVA
          when 1000..16000
              phases = 3
              voltage_default = 12.47
              simulteneity_factor = 0.8 # default value
              peak_active_power_CF = peak_active_power*simulteneity_factor
              reactive_power_CF = reactive_power*simulteneity_factor
          else
              # HV and 3 phases for over 16 MVA
              phases = 3
              voltage_default = 69
              simulteneity_factor = 1 # default value
              peak_active_power_CF = peak_active_power*simulteneity_factor
              reactive_power_CF = reactive_power*simulteneity_factor
        end
        # creating the customer_ext array with the obtained values
        customer = building_map, voltage_default, peak_active_power, reactive_power, phases
        customers_ext = building_map, voltage_default, peak_active_power, reactive_power, phases, area, height, energy.round(2), peak_active_power_CF.round(2), reactive_power_CF.round(2), users
        return customers_ext, customer
      end
    end
  end 
end 
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
		# creating a class where the URBANopt files are read and the needed data is loaded in arrays
		class Dataload
	    # creating a method passing the GeoJSON file from URBANopt as the argument to define streets and building (customers) coordinates
	    # and returning the street coordinates array, the building coordinates array and the tot number of buildings in the project
	    def coordinates_file_load(geojson_file)
	        i = 0 # index representing the number of street_nodes
	        building_number = 0 # variable created to keep track the number of building in the example_project
	        customers_coordinates = [] # array containing the coordinates and id of the closest node of each building to the street
	        street_coordinates = [] # array containing every street node coordinates and id
	        coordinates_buildings = [] # array containing every building node coordinates and id
	        building_ids = [] # array containing building_ids to retrieve urbanopt results later
	        streets = JSON.parse(geojson_file)
	        # each features (linestring, multilinestring and polygon) are processed in an external method, to create intermediate nodes
	        # for a better graphical representation of the district 
	        # "Point" geometry is ignored (site origin feature)
	        streets['features'].each do |street|
	            for k in 0..street['geometry']['coordinates'].length-1 
	                # the geojson file is read and according to the "type" of feature (linestring, multilinestring, polygon)
	                # a different loop is executed to fill every node coordinates in a specific array 
	                if street['geometry']['type'] == "LineString"
	                    street_coordinates, i = URBANopt::RNM::Processor.new.coordinates(street, street['geometry']['coordinates'][k][1], street['geometry']['coordinates'][k][0], street_coordinates, k, i) 
	                elsif street['geometry']['type'] == "MultiLineString"
	                      for j in 0..street['geometry']['coordinates'][k].length-1
	                          street_coordinates, i = URBANopt::RNM::Processor.new.coordinates(street, street['geometry']['coordinates'][k][j][1], street['geometry']['coordinates'][k][j][0], coordinates, j, i)
	                      end
	                elsif street['geometry']['type'] == "Polygon"
	                    h = 0 # index representing number of nodes for each single building
	                    building = [] # array containing every building node coordinates and id of 1 building
	                    for j in 0..street['geometry']['coordinates'][k].length-1
	                        building, h = URBANopt::RNM::Processor.new.coordinates(street, street['geometry']['coordinates'][k][j][1], street['geometry']['coordinates'][k][j][0], building, j, h) 
	                    end 
	                    coordinates_buildings[building_number] = building # inserting in each index the nodes coordinates and id of each building
	                    building_ids[building_number] = street['properties']['id']
	                    building_number += 1
	                end
	            end
	        end 
	        # an external method is called to find the coordinates of the closest node of each building to the street
	            for i in 0..building_number-1
	                customers_coordinates[i] = URBANopt::RNM::Processor.new.consumer_coordinates(coordinates_buildings[i], street_coordinates)
	            end
	        return street_coordinates, customers_coordinates, building_number, building_ids
	    end
	    # defining a method for the customers_ext file creation: 
	    # obtaining all the needed input from each feature_report.csv file (active & apparent power and tot energy consumed)
	    # and from each feature_report.json file (area, height, number of users)
	    # the method passes as arguments each urbanopt json and csv output file for each feature and the building coordinates previously calculated
	    # and returns an array containing all the data for the creation of the customer_ext.txt file
	    def customer_files_load(csv_feature_report, json_feature_report, building_map)
	        active_power = []
	        apparent_power = []
	        energy = 0
	        k = 0   # index for each hour of the year represented in the csv file 
	        content = CSV.foreach(csv_feature_report, headers: true) do |power|
	            active_power[k] = power["Net Power(kW)"].to_f
	            apparent_power[k] = power["Net Apparent Power(kVA)"].to_f
	            energy += power["Electricity:Facility(kWh)"].to_f # calculating the yearly energy consumed by each feature
	            k+=1
	        end 
	        folder =  JSON.parse(json_feature_report) 
	        area = (folder['program']['floor_area']).round(2)
	        height = (folder['program']['maximum_roof_height']).round(2)
	        users = folder['program']['number_of_residential_units']
	        # calling an external method to construct the customer_ext array
	        customer_ext, customer = URBANopt::RNM::Processor.new.construct_customer(active_power, apparent_power, energy, building_map, area, height, users)
	        return customer_ext, customer
	    end
		end
  end
end

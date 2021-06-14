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
	class Report_scenario
		attr_accessor :hour_index_max, :hour_index_min, :peak_hour_max, :peak_hour_min
		def initialize(reopt)
            @reopt = reopt
			@hour_index_max = hour_index_max
			@hour_index_min = hour_index_min
			@peak_hour_max = peak_hour_max
			@peak_hour_min = peak_hour_min
		end
		# creating a method passing the GEOjson file from URBANopt as the argument to define streets and building (customers) coordinates
		# and returning the street coordinates array, the building coordinates array and the tot number of buildings in the project
		
		def scenario_report_results(report_file)
			max_net_load = 0
			min_net_load = 500000
			j = 0
			# insert scenario path
			#if include reopt getting 2 most-stressing days in the year (max net load & min net load)
			if @reopt
				CSV.foreach(report_file, headers: true) do |power|
					net_load = power['REopt:Electricity:Load:Total(kw)'].to_i + power['REopt:Electricity:Grid:ToBattery(kw)'].to_i + power['REopt:ElectricityProduced:PV:ToBattery(kw)'].to_i + power['REopt:ElectricityProduced:Wind:ToBattery(kw)'].to_i + power['REopt:ElectricityProduced:Generator:ToBattery(kw)'].to_i - power['REopt:Electricity:Storage:ToLoad(kw)'].to_i - power['REopt:Electricity:Storage:ToGrid(kw)'].to_i - power['REopt:ElectricityProduced:Total(kw)'].to_i
					if net_load > max_net_load
						max_net_load = net_load
						@peak_hour_max = (power['Datetime'].split(' ')[1]).split(':')[0].to_i # defined the most-stressing scenario
						@hour_index_max = j
					end
					if net_load < min_net_load
						min_net_load = net_load
						@peak_hour_min = power['Datetime'].split(' ')[1].split(':')[0].to_i # defined the most-stressing scenario
						@hour_index_min = j
					end
					j += 1
				end
			else # case when reopt is not run and there is only a consumption scenario, without DG generation
				CSV.foreach(report_file, headers: true) do |power|
					net_load = power['Net Power(kW)'].to_i
					if net_load > max_net_load
						max_net_load = net_load
						@peak_hour_max = power['Datetime'].split(' ')[1].split(':')[0].to_i # defined the most-stressing scenario
						@hour_index_max = j
					end
					j += 1
				end
			end
		end
	end
end
end
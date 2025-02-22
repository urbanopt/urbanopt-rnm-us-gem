# *********************************************************************************
# URBANopt™, Copyright © Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-rnm-us-gem/blob/develop/LICENSE.md
# *********************************************************************************

module URBANopt
  module RNM
    class ReportScenario
      attr_accessor :hour_index_max_res, :hour_index_min_res, :peak_hour_max_res, :peak_hour_min_res, :hour_index_max_comm, :hour_index_min_comm, :peak_hour_max_comm, :peak_hour_min_comm

      def initialize(reopt)
        @reopt = reopt
        @hour_index_max_res = hour_index_max_res
        @hour_index_min_res = hour_index_min_res
        @peak_hour_max_res = peak_hour_max_res
        @peak_hour_min_res = peak_hour_min_res
        @hour_index_max_comm = hour_index_max_comm
        @hour_index_min_comm = hour_index_min_comm
        @peak_hour_max_comm = peak_hour_max_comm
        @peak_hour_min_comm = peak_hour_min_comm
        @res_consumption = []
        @commercial_consumption = []
        @time = []
      end

      # creating a method passing the GEOjson file from URBANopt as the argument to define streets and building (customers) coordinates
      # and returning the street coordinates array, the building coordinates array and the tot number of buildings in the project

      def scenario_report_results
        max_net_load_res = 0
        max_net_load_comm = 0
        min_net_load_res = 500000
        min_net_load_comm = 500000
        # j = 0
        # insert scenario path
        # if include reopt getting 2 most-stressing days in the year (max net load & min net load)
        if @reopt
          (0..@commercial_consumption.length - 1).each do |j|
            if @commercial_consumption[j] > max_net_load_comm
              max_net_load_comm = @commercial_consumption[j]
              @peak_hour_max_comm = (@time[j].split(' ')[1]) # defined the most-stressing scenario
              @hour_index_max_comm = j
            end
            if @commercial_consumption[j] < min_net_load_comm
              min_net_load_comm = @commercial_consumption[j]
              @peak_hour_min_comm = (@time[j].split(' ')[1]) # defined the most-stressing scenario
              @hour_index_min_comm = j
            end

            if @res_consumption[j] > max_net_load_res
              max_net_load_res = @res_consumption[j]
              @peak_hour_max_res = (@time[j].split(' ')[1]) # defined the most-stressing scenario
              @hour_index_max_res = j
            end
            if @res_consumption[j] < min_net_load_res
              min_net_load_res = @res_consumption[j]
              @peak_hour_min_res = (@time[j].split(' ')[1]) # defined the most-stressing scenario
              @hour_index_min_res = j
            end
          end

        else # case when reopt is not run and there is only a consumption scenario, without DG generation
          (0..@commercial_consumption.length - 1).each do |j|
            if @commercial_consumption[j] > max_net_load_comm
              max_net_load_comm = @commercial_consumption[j]
              @peak_hour_max_comm = (@time[j].split(' ')[1]) # defined the most-stressing scenario
              @hour_index_max_comm = j
            end
            if @res_consumption[j] > max_net_load_res
              max_net_load_res = @res_consumption[j]
              @peak_hour_max_res = (@time[j].split(' ')[1]) # defined the most-stressing scenario
              @hour_index_max_res = j
            end
          end
        end
      end

      def aggregate_consumption(file_csv, file_json, n_feature)
        feature_type = file_json['program']['building_types'][0]['building_type']
        # residential_building_types = "Single-Family Detached" #add the other types
        residential_building_types = ['Single-Family Detached', 'Single-Family Attached', 'Multifamily', 'Single-Family', 'Multifamily Detached (2 to 4 units)', 'Multifamily Detached (5 or more units)'] # add the other types
        puts feature_type
        j = 0
        CSV.foreach(file_csv, headers: true) do |power|
          @time[j] = power['Datetime']
          if n_feature == 0
            @res_consumption[j] = 0
            @commercial_consumption[j] = 0
          end
          if @reopt
            if residential_building_types.include? feature_type
              @res_consumption[j] += power['REopt:Electricity:Load:Total(kw)'].to_i + power['REopt:Electricity:Grid:ToBattery(kw)'].to_i + power['REopt:ElectricityProduced:PV:ToBattery(kw)'].to_i + power['REopt:ElectricityProduced:Wind:ToBattery(kw)'].to_i + power['REopt:ElectricityProduced:Generator:ToBattery(kw)'].to_i - power['REopt:Electricity:Storage:ToLoad(kw)'].to_i - power['REopt:Electricity:Storage:ToGrid(kw)'].to_i - power['REopt:ElectricityProduced:Total(kw)'].to_i
              j += 1
            else
              @commercial_consumption[j] += power['REopt:Electricity:Load:Total(kw)'].to_i + power['REopt:Electricity:Grid:ToBattery(kw)'].to_i + power['REopt:ElectricityProduced:PV:ToBattery(kw)'].to_i + power['REopt:ElectricityProduced:Wind:ToBattery(kw)'].to_i + power['REopt:ElectricityProduced:Generator:ToBattery(kw)'].to_i - power['REopt:Electricity:Storage:ToLoad(kw)'].to_i - power['REopt:Electricity:Storage:ToGrid(kw)'].to_i - power['REopt:ElectricityProduced:Total(kw)'].to_i
              j += 1
            end
          else
            if residential_building_types.include? feature_type
              @res_consumption[j] += power['Electricity:Facility Power(kW)'].to_i
              j += 1
            else
              @commercial_consumption[j] += power['Electricity:Facility Power(kW)'].to_i
              j += 1
            end
          end
        end
      end
    end
  end
end

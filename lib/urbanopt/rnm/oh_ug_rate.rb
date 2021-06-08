require 'rubygems'
require 'json'
require 'csv'
require 'geoutm'
module URBANopt
    module RNM
        class Oh_ug_rate
            attr_accessor :av_height, :type, :h_threshold, :n_buildings_street
            def initialize()
                @av_height = av_height
                @type = type
                @n_buildings_street = n_buildings_street
            end
            # for each street calculate the average height given the buildings in the streets
            def height_building(coordinates_building, coordinates_street, floors)
                height = []
                id_building = []
                height_sum = 0
                n_buildings_street = 0
                for i in 0..coordinates_street.length-1
                    dist_min = 5000
                    for j in 0..floors.length-1
                        for k in 0..coordinates_building[j].length-1
                            y = coordinates_building[j][k][1]-coordinates_street[i][1]
                            x = coordinates_building[j][k][0]-coordinates_street[i][0]
                            distance = (x + y)/2 # finding the distance of each building node with each street node
                            if distance < dist_min
                                distance = ((x)**2 + (y)**2)**(0.5)
                                if distance < dist_min
                                    dist_min = distance
                                    height[i] = floors[j]
                                    id_building[i] = coordinates_building[j][k][3].split('_')[0] #for future implementations set as attributes :id, :coordinates
                                end
                            end
                        end 
                    end
                    ii = 0
                    while ii != i &&  id_building[i] != id_building[ii] #id_building[ii] != id_bui
                        ii += 1
                        if ii == i 
                            n_buildings_street += 1
                        end
                    end
                    height_sum += height[i]
                end
                    @n_buildings_street = n_buildings_street
                    @av_height = (height_sum / (i+1)).to_f.round(2)
                #return @av_height, @n_buildings_street
            end
            def threshold_height(street_type, ug_ratio)
                h_threshold = 0
                tot_build_in_streets = 0
                n_street_oh = []
                for i in 0..street_type.length-1
                    tot_build_in_streets += street_type[i].n_buildings_street
                end
                street_set_oh = ((tot_build_in_streets)*(1-ug_ratio)).to_i
                ii = 0
                while  ii == 0 || n_street_oh[ii-1] < street_set_oh 
                    n_street_oh[ii] = 0
                    for i in 0..street_type.length-1
                        if street_type[i].av_height < h_threshold
                            n_street_oh[ii] += street_type[i].n_buildings_street #qui sommo numero di palazzi per ognuna di queste strade (n_build_oh += street_type.n_build)
                        end
                    end
                    ii += 1 
                    h_threshold += 0.10
                end 
                h_threshold = h_threshold - 0.10
                return h_threshold.to_i
                # if (n_street_oh[ii-1] - street_set_oh).abs < (n_street_oh[ii - 2] - street_set_oh).abs
                #     return h_threshold 
                # else
                #     return h_threshold - 0.2
                # end
            end
            def classify_street_type(street_type, ug_ratio)
                h = self.threshold_height(street_type, ug_ratio)
                if @av_height < h
                    @type = 'A' #'OH'
                else
                    @type = 'S' #'UG'
                end
            end
        end
    end
end
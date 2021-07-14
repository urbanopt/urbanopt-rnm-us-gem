# *********************************************************************************
# URBANopt™, Copyright (c) 2019-2021, Alliance for Sustainable Energy, LLC, and other
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

# find when the power lines in a street have to be considered OH or UG
# according to a threshold height obtained from the %UG defined by the user
module URBANopt
    module RNM
        class Oh_ug_rate
            attr_accessor :av_height, :type, :n_buildings_street
            def initialize()
                @av_height = av_height
                @type = type
                @n_buildings_street = n_buildings_street
            end
            # for each street calculate the average height given the buildings in the streets
            #and it calculates the number of buildings in each street
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
            end

            # defining a method which defines the "threshold height", in an iterative way and adding 0.1m of height until the threhold limit is reached
            # when the % of streets in the district above the threshold is equal to the UG rate defined by the user 
            def threshold_height(street_type, ug_ratio)
                h_threshold = 0
                tot_build_in_streets = 0
                n_street_oh = []
                for i in 0..street_type.length-1
                    tot_build_in_streets += street_type[i].n_buildings_street
                end
                #puts tot_build_in_streets
                street_set_oh = ((tot_build_in_streets)*(1-ug_ratio)).round
                ii = 0
                while  ii == 0 || n_street_oh[ii-1] < street_set_oh 
                    n_street_oh[ii] = 0
                    for i in 0..street_type.length-1
                        if street_type[i].av_height < h_threshold
                            n_street_oh[ii] += street_type[i].n_buildings_street 
                        end
                    end
                    ii += 1 
                    h_threshold += 0.10
                end 
                h_threshold = h_threshold - 0.10
                return h_threshold
            end
            # defining a method that decides to place each street either OH or UG, according to its average height and the threshold height,
            # if the street has a height below the threshold height it has to modelled has OH, otherwise UG
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
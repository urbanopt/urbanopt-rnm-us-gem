
# version for integrating DG, UG-OH in RNM-US
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
require 'json'
module URBANopt
    module RNM
        class Primary_substation
            #attr_accessor :x, :y, :id
            def coordinates(points_coord, id) #choose the closes coord to the street or the one in the midle of the polygon since the sub is far away from district and streets
                x_utm = []
                y_utm = []
                for i in 0..points_coord.length-1
                    lat_lon = GeoUtm::LatLon.new(points_coord[i][1], points_coord[i][0])
                    utm = lat_lon.to_utm # converting latitude and longitude to UTM
                    x_utm[i] = utm.e.round(2) # UTM x-distance from the origin
                    y_utm[i] = utm.n.round(2) # UTM y-distance from the origin
                end
                coord_sub = [(x_utm[0]+ x_utm[2])/2, (y_utm[0] + y_utm[2])/2, 0, "sub_" + id]
                return coord_sub
            end
        end
    end
end
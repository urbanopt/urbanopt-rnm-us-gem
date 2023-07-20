# *********************************************************************************
# URBANopt™, Copyright © Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-rnm-us-gem/blob/develop/LICENSE.md
# *********************************************************************************

# version for integrating DG, UG-OH in RNM-US
require 'geoutm'
require 'json'
module URBANopt
  module RNM
    class PrimarySubstation
      # attr_accessor :x, :y, :id
      # choose the closest coord to the street or the one in the midle of the polygon since the sub is far away from district and streets
      def coordinates(points_coord, id)
        x_utm = []
        y_utm = []
        for i in 0..points_coord.length - 1
          lat_lon = GeoUtm::LatLon.new(points_coord[i][1], points_coord[i][0])
          utm = lat_lon.to_utm # converting latitude and longitude to UTM
          x_utm[i] = utm.e.round(2) # UTM x-distance from the origin
          y_utm[i] = utm.n.round(2) # UTM y-distance from the origin
        end
        coord_sub = [(x_utm[0] + x_utm[2]) / 2, (y_utm[0] + y_utm[2]) / 2, 0, "sub_#{id}"]
        return coord_sub
      end
    end
  end
end

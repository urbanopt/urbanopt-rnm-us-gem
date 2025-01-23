# *********************************************************************************
# URBANopt™, Copyright © Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-rnm-us-gem/blob/develop/LICENSE.md
# *********************************************************************************

require 'urbanopt/rnm/logger'
require 'json'
require 'csv'
require 'set'
require 'matrix'

module URBANopt
  module RNM
    class WiresExtendedCatalog
      attr_accessor :x, :height, :gmr, :r, :ampacity, :diameter, :phase, :name, :type, :r_neutral, :gmr_neutral, :neutral_strands, :diameter_n_strand, :outside_diameter_neutral

      def initialize
        self.x = []
        self.height = []
        self.gmr = []
        self.r = []
        self.ampacity = []
        self.diameter = []
        self.phase = []
        self.name = []
        self.type = []
        self.r_neutral = []
        self.gmr_neutral = []
        self.neutral_strands = []
        self.diameter_n_strand = []
        self.outside_diameter_neutral = []
      end
    end
  end
end

# *********************************************************************************
# URBANopt™, Copyright © Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-rnm-us-gem/blob/develop/LICENSE.md
# *********************************************************************************
module URBANopt
  module RNM
    # class created to verify that if a component is repeated more than once in the extended catalog
    # than it is parsed only one time for the OpenDSS catalog
    class ProcessorOpendss
      attr_accessor :cont, :list

      def initialize
        @list = list
        @cont = cont
      end

      def process_data(catalog_data)
        for kk in 0..catalog_data.length - 1 # inside each component
          zz = 0
          if @list.nil?
            @cont = 0
            @list = []
          else
            if catalog_data[kk].include? 'Probability' # referring to transformers
              zz += 1 while zz < @cont && @list[zz]['Name'] != catalog_data[kk]['Name']
            else
              zz += 1 while zz < @cont && @list[zz] != catalog_data[kk]
            end
          end
          if zz == @cont
            @list[@cont] = catalog_data[kk] # associating conductores values in this list
            @cont += 1
          end
        end
      end
    end
  end
end

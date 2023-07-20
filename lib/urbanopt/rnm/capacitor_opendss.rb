# *********************************************************************************
# URBANopt™, Copyright © Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-rnm-us-gem/blob/develop/LICENSE.md
# *********************************************************************************

module URBANopt
  module RNM
    # creating the Capacitor class with required parameters by the OpenDSS catalog
    class Capacitor
      def create(capacitor)
        hash = {}
        hash[:nameclass] = capacitor[' Name']
        hash[:kvar] = capacitor[' size (kVA)']
        hash[:resistance] = capacitor['resistance(Ohm)']
        hash[:phases] = capacitor[' number of phases']
        hash[:connection] = capacitor['connection']
        hash[:control_type] = capacitor['control_type']
        return hash
      end
    end
  end
end

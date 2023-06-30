# *********************************************************************************
# URBANopt™, Copyright © Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-rnm-us-gem/blob/develop/LICENSE.md
# *********************************************************************************
module URBANopt
  module RNM
    # creating the Transformers class with required parameters by the OpenDSS catalog
    class Transformers
      def create(trafo)
        hash = {}
        hash[:nameclass] = trafo['Name']
        if trafo.include? 'Installed Power(MVA)'
          hash[:kva] = (trafo['Installed Power(MVA)'].to_i * 1000).to_i # converting to kVA
        else # trafo.include? "kVA"
          hash[:kva] = trafo['Installed Power(kVA)']
        end
        hash[:resistance] = trafo['Low-voltage-side short-circuit resistance (ohms)'].to_f.round(2)
        hash[:reactance] = trafo['Reactance (p.u. transf)'].to_f.round(2)
        hash[:phases] = trafo['Nphases']
        hash[:Centertap] = trafo['Centertap']
        hash[:high_voltage] = trafo['Primary Voltage (kV)']
        hash[:low_voltage] = trafo['Secondary Voltage (kV)']
        hash[:connection] = trafo['connection']
        return hash
      end
    end
  end
end

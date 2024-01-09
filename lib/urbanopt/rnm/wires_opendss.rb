# *********************************************************************************
# URBANopt™, Copyright © Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-rnm-us-gem/blob/develop/LICENSE.md
# *********************************************************************************
module URBANopt
  module RNM
    # creating the WiresOpendss class with required parameters by the OpenDSS catalog
    class WiresOpendss
      attr_accessor :fields, :value

      def initialize
        self.value = []
        self.fields = []
      end

      def create(line_geometry, conductor)
        # providing all info in ft
        hash = {}
        conductor.each do |k, v|
          if k.include? '(mm)'
            # new_key = "#{k.sub('(mm)', '')}(ft)"
            new_key = k.sub(' (mm)', '').gsub(' ', '_').to_s
            hash[new_key] = v
          elsif k.include? '(A)'
            new_key = k.sub(' (A)', '').gsub(' ', '_').to_s
            hash[new_key] = v
          elsif k.include? '#'
            new_key = k.sub('#', 'num').gsub(' ', '_').to_s
            hash[new_key] = v
          elsif k.include? '(ohm/km)'
            # new_key = "#{k.sub('(ohm/km)', '')}(ohm/mi)"
            new_key = k.sub(' (ohm/km)', '').gsub(' ', '_').to_s
            hash[new_key] = v
          elsif k != 'voltage level' && k != 'type'
            new_key = k.gsub(' ', '_').to_s
            hash[new_key] = v
          else
            new_key = k.gsub(' ', '_').to_s
            hash[new_key] = v
          end
        end
        line_geometry.each do |k, v|
          hash[k] = v
          if k.include? 'wire'
            hash.delete(k)

          elsif k.include? '(m)'
            hash.delete(k)
            k = k.split(' ')[0]
            new_key = k.sub(' ', '_').to_s
            hash[new_key] = v
          end
        end
        return hash
      end
    end
  end
end

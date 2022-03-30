# *********************************************************************************
# URBANopt (tm), Copyright (c) 2019-2022, Alliance for Sustainable Energy, LLC, and other
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
# originally provided by Alliance as "URBANopt". Except to comply with the foregoing,
# the term "URBANopt", or any confusingly similar designation may not be used to
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
            new_key = "#{k.sub(' (mm)', '').gsub(' ','_')}"
            hash[new_key] = v
          elsif k.include? '(A)'
            new_key = "#{k.sub(' (A)', '').gsub(' ','_')}"
            hash[new_key] = v
          elsif k.include? '#'
            new_key = "#{k.sub('#', 'num').gsub(' ', '_')}"
            hash[new_key] = v
          elsif k.include? '(ohm/km)'
            # new_key = "#{k.sub('(ohm/km)', '')}(ohm/mi)"
            new_key = "#{k.sub(' (ohm/km)', '').gsub(' ','_')}"
            hash[new_key] = v
          elsif k != 'voltage level' && k != 'type'
            new_key = "#{k.gsub(' ', '_')}"
            hash[new_key] = v
          else
            new_key = "#{k.gsub(' ', '_')}"
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
            new_key = "#{k.sub(' ', '_')}"
            hash[new_key] = v
          end
        end
        return hash
      end
    end
  end
end

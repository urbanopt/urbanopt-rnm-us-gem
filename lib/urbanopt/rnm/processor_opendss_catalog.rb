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
module URBANopt
    module RNM
        # class created to verify that if a component is repeated more than once in the extended catalog
        # than it is parsed only one time for the OpenDSS catalog
        class Processor_opendss
            attr_accessor :cont, :list
            def initialize
                @list = list
                @cont = cont
            end
            def process_data(catalog_data)
            for kk in 0..catalog_data.length-1 #inside each component
                zz = 0
                if @list == nil
                    @cont = 0
                    @list = Array.new
                else
                    if catalog_data[kk].include? "Probability" #referring to transformers
                        while zz < @cont && @list[zz]["Name"] != catalog_data[kk]["Name"]
                            zz += 1
                        end
                    else
                        while zz < @cont && @list[zz] != catalog_data[kk]
                            zz += 1
                        end
                    end
                end
                if zz == @cont
                    @list[@cont] = catalog_data[kk] #associating conductores values in this list
                    @cont += 1
                end
            end
            end
        end
    end
end
        
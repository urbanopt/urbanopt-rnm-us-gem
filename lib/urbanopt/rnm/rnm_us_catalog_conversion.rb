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
require 'json'
require 'urbanopt/rnm/logger'

module URBANopt
  module RNM
    # creating a class to convert the extended catalog into the RNM-US catalog which is needed by the model
        class Rnm_us_catalog_conversion
            def initialize(extended_catalog_path, run_dir, rnm_dirname)
                @extended_catalog_path = extended_catalog_path
                @run_dir = run_dir
                @rnm_dirname = rnm_dirname
            end
            def matrix_processing(csv, matrix, v, row, section, wires, k)
                if matrix.is_a?(Array)
                    csv << row
                    headings = Array.new
                    for j in 0..matrix.length-1
                        if section == "LINES"
                            if matrix[j]['Line geometry'].is_a? Array
                                line_creation = URBANopt::RNM::Carson_eq.new(matrix[j])
                                matrix[j] = line_creation.creation(wires) #passing the info about each power line
                            else
                                matrix[j].delete("Line geometry")
                            end
                        end
                        ii = 0
                        matrix[j].each do |keys,values|
                            matrix[j].delete('connection')
                            matrix[j].delete('resistance(Ohm)')
                            matrix[j].delete('control_type')
                            if ii == 0
                                headings[ii] = "#" + keys #to ensure it works with the catalog
                            else
                                headings[ii] = keys
                            end
                            row[ii] = values
                            ii += 1
                        end
                        if j == 0
                            csv << headings
                        end
                        csv << row
                        
                    end
                else
                    if k == ("Mismatch voltages S (kV):").to_s  || k == "Mismatches convergence S (kVA):" || k =="Minimum allowable voltages (pu):" || k == "Maximum allowable voltages (pu):"
                        for i in 0..v.split(',').length-1
                            row.push(v.split(',')[i])
                        end
                    else
                        row.push(v) 
                    end
                    csv << row
                end
            end
            def processing_data
                #parsing lines and wires info:
                row = Array.new(25)
                ext_catalog = JSON.parse(File.read(@extended_catalog_path))
                CSV.open(File.join(@run_dir, @rnm_dirname, "udcons.csv"), "w") do |csv|
                    ext_catalog.each do |key,v|
                        if key != "WIRES"
                            csv << ["<"+ "#{key}" + ">"]                 
                                if ext_catalog[key].is_a?(Hash) #defining the section under consideration is an Hash or an Array
                                    ext_catalog[key].each do |k,v|
                                        row = Array.new
                                        row.push(k) #title of the array
                                        self.matrix_processing(csv, ext_catalog[key][k],v, row, key, ext_catalog['WIRES'], k )
                                    end
                                else
                                    if ext_catalog[key].length == 0
                                        csv << ['END']
                                    else                                  
                                        for i in 0..ext_catalog[key].length-1 
                                            row = Array.new
                                            if ext_catalog[key][i].is_a?(Hash)
                                                ext_catalog[key][i].each do |k,v|
                                                row.push(k)  #title of the array
                                                self.matrix_processing(csv, ext_catalog[key][i][k],v, row, key, ext_catalog['WIRES'], k)
                                                    if key == "LINES" || key == "SUBSTATIONS AND DISTRIBUTION TRANSFORMERS" || key == "CAPACITORS"
                                                            csv <<['END']
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            csv << ["</"+ "#{key}" + ">"]
                        end
                    end
                end
            end
        end
    end
end


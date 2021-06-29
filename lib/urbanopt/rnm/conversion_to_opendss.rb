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
module URBANopt
  module RNM
    # class created to convert the extended catalog into the OpenDSS catalog to be used by the OpenDSS Gem
    class Conversion_to_opendss_catalog
      attr_accessor :hash
      def initialize(extended_catalog_path)
        @extended_catalog_path = extended_catalog_path
        @hash = hash
      end
      # method to convert initial SI units in the ext catalog into Imperial units used by the Carson equation
      def convert_to_imperial_units(hash)
        hash_new = {}
        hash.each do |k,v|
          if k.include? '(mm)'
              mm_ft = 0.00328
              hash_new[k] = (v * mm_ft).round(5)
          elsif k.include? '(ohm/km)'
              km_miles = 0.6214
              hash_new[k] = (v / km_miles).round(2)
          elsif k.include? '(m)'
              m_ft = 3.281
              hash_new[k] =  (v * m_ft).round(2)
          else
              hash_new[k] = hash[k]
          end
        end
        return hash_new
      end

      def create_catalog(save_path)
        @hash = {}
        component = Array.new
        catalog = JSON.parse(File.read(@extended_catalog_path))
        i = 0
        z = 0

        catalog.each do |key, value|
          if key == 'SUBSTATIONS AND DISTRIBUTION TRANSFORMERS'
            transformers = URBANopt::RNM::Processor_opendss.new()
            component = Array.new
            for ii in 0..catalog[key].length-1 #assessing each type of transformer (Urban, Inter)
              catalog[key][ii].each do |k, v|
                # calling a method to verify that the same transformers are not repeated in the OpenDSS catalog
                transformers.process_data(catalog[key][ii][k])
              end
            end
            for i in 0..transformers.list.length-1
              trafo = URBANopt::RNM::Transformers.new()
              component.push(trafo.create(transformers.list[i]))
            end
            @hash['transformers_properties'] = component
          elsif key == 'CAPACITORS'
            capacitors = URBANopt::RNM::Processor_opendss.new()
            component = Array.new
            catalog[key].each do |k,v|
              # calling a method to verify that the same capacitors are not repeated in the OpenDSS catalog
              capacitors.process_data(catalog[key][k])
              for i in 0..capacitors.list.length-1
                capacitor = URBANopt::RNM::Capacitor.new()
                component.push(capacitor.create(capacitors.list[i]))
              end
            end
            @hash['capacitor_properties'] = component
          elsif key == 'LINES'
            @conductors = URBANopt::RNM::Processor_opendss.new()
            component=Array.new
            for ii in 1..catalog[key].length-1
              catalog[key][ii].each do |k,v| #assessing if interurban section, urban section, etc.
                for jj in 0..catalog[key][ii][k].length-1 #assessing each power line
                  catalog[key][ii][k][jj].each do |attribute, values|
                    if attribute == "Line geometry"
                      # calling a method to verify that the same lines are not repeated in the OpenDSS catalog
                      @conductors.process_data(catalog[key][ii][k][jj][attribute])
                    end
                  end
                end 
              end
            end
          end
        end

        key = 'WIRES'
        component = Array.new
        updated_value = 0
        i = 0 #counter for all the lines in the OpenDSS catalog
        catalog[key].each do |k,v|
          for jj in 0..@conductors.cont-1
            for ii in 0..catalog[key][k].length-1
              if @conductors.list[jj]['wire'] == catalog[key][k][ii]['nameclass']
                @conductors.list[jj] = self.convert_to_imperial_units(@conductors.list[jj])
                updated_value = self.convert_to_imperial_units(catalog[key][k][ii])
                wire = URBANopt::RNM::Wires_opendss.new()
                component.push(wire.create(@conductors.list[jj], updated_value))
                i += 1
              end
            end
          end
        end
        @hash['wires'] = component

        # save to save_path
        File.open(save_path,"w") do |f|
          f.write(JSON.pretty_generate(@hash))
        end
      end
    end
  end
end
      
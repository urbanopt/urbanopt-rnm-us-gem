# *********************************************************************************
# URBANopt™, Copyright © Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-rnm-us-gem/blob/develop/LICENSE.md
# *********************************************************************************

require 'json'
module URBANopt
  module RNM
    # class created to convert the extended catalog into the OpenDSS catalog to be used by the OpenDSS Gem
    class ConversionToOpendssCatalog
      attr_accessor :hash

      def initialize(extended_catalog_path)
        @extended_catalog_path = extended_catalog_path
        @hash = hash
      end

      # method to convert initial SI units in the ext catalog into Imperial units used by the Carson equation
      def convert_to_imperial_units(hash)
        hash_new = {}
        hash.each do |k, v|
          if k.include? '(mm)'
            mm_ft = 0.00328
            hash_new[k] = (v * mm_ft).round(5)
          elsif k.include? '(ohm/km)'
            km_miles = 0.6214
            hash_new[k] = (v / km_miles).round(2)
          elsif k.include? '(m)'
            m_ft = 3.281
            hash_new[k] = (v * m_ft).round(2)
          else
            hash_new[k] = hash[k]
          end
        end
        return hash_new
      end

      def create_catalog(save_path)
        @hash = {}
        component = []
        catalog = JSON.parse(File.read(@extended_catalog_path))
        i = 0
        z = 0

        catalog.each do |key, value|
          case key
          when 'SUBSTATIONS AND DISTRIBUTION TRANSFORMERS'
            transformers = URBANopt::RNM::ProcessorOpendss.new
            component = []
            for ii in 0..catalog[key].length - 1 # assessing each type of transformer (Urban, Inter)
              catalog[key][ii].each do |k, v|
                # calling a method to verify that the same transformers are not repeated in the OpenDSS catalog
                transformers.process_data(catalog[key][ii][k])
              end
            end
            for i in 0..transformers.list.length - 1
              trafo = URBANopt::RNM::Transformers.new
              component.push(trafo.create(transformers.list[i]))
            end
            @hash['transformers_properties'] = component
          when 'CAPACITORS'
            capacitors = URBANopt::RNM::ProcessorOpendss.new
            component = []
            catalog[key].each do |k, v|
              # calling a method to verify that the same capacitors are not repeated in the OpenDSS catalog
              capacitors.process_data(catalog[key][k])
              for i in 0..capacitors.list.length - 1
                capacitor = URBANopt::RNM::Capacitor.new
                component.push(capacitor.create(capacitors.list[i]))
              end
            end
            @hash['capacitor_properties'] = component
          when 'LINES'
            @conductors = URBANopt::RNM::ProcessorOpendss.new
            component = []
            for ii in 1..catalog[key].length - 1
              catalog[key][ii].each do |k, v| # assessing if interurban section, urban section, etc.
                for jj in 0..catalog[key][ii][k].length - 1 # assessing each power line
                  catalog[key][ii][k][jj].each do |attribute, values|
                    if attribute == 'Line geometry'
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
        component = []
        updated_value = 0
        i = 0 # counter for all the lines in the OpenDSS catalog
        catalog[key].each do |k, v|
          for jj in 0..@conductors.cont - 1
            for ii in 0..catalog[key][k].length - 1
              if @conductors.list[jj]['wire'] == catalog[key][k][ii]['nameclass']
                @conductors.list[jj] = convert_to_imperial_units(@conductors.list[jj])
                updated_value = convert_to_imperial_units(catalog[key][k][ii])
                wire = URBANopt::RNM::WiresOpendss.new
                component.push(wire.create(@conductors.list[jj], updated_value))
                i += 1
              end
            end
          end
        end
        @hash['wires'] = component

        # save to save_path
        File.open(save_path, 'w') do |f|
          f.write(JSON.pretty_generate(@hash))
        end
      end
    end
  end
end

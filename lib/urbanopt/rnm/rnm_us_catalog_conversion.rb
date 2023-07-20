# *********************************************************************************
# URBANopt™, Copyright © Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-rnm-us-gem/blob/develop/LICENSE.md
# *********************************************************************************

require 'json'
require 'urbanopt/rnm/logger'

module URBANopt
  module RNM
    # creating a class to convert the extended catalog into the RNM-US catalog which is needed by the model
    class RnmUsCatalogConversion
      def initialize(extended_catalog_path, run_dir, rnm_dirname)
        @extended_catalog_path = extended_catalog_path
        @run_dir = run_dir
        @rnm_dirname = rnm_dirname
      end

      def matrix_processing(csv, matrix, v, row, section, wires, k)
        if matrix.is_a?(Array)
          csv << row
          headings = []
          for j in 0..matrix.length - 1
            if section == 'LINES'
              if matrix[j]['Line geometry'].is_a? Array
                line_creation = URBANopt::RNM::CarsonEq.new(matrix[j])
                matrix[j] = line_creation.creation(wires) # passing the info about each power line
              else
                matrix[j].delete('Line geometry')
              end
            end
            ii = 0
            matrix[j].each do |keys, values|
              matrix[j].delete('connection')
              matrix[j].delete('resistance(Ohm)')
              matrix[j].delete('control_type')
              if ii == 0
                headings[ii] = "##{keys}" # to ensure it works with the catalog
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
          if k == 'Mismatch voltages S (kV):'.to_s || k == 'Mismatches convergence S (kVA):' || k == 'Minimum allowable voltages (pu):' || k == 'Maximum allowable voltages (pu):'
            for i in 0..v.split(',').length - 1
              row.push(v.split(',')[i])
            end
          else
            row.push(v)
          end
          csv << row
        end
      end

      def processing_data(utm_zone)
        # parsing lines and wires info:
        row = Array.new(25)
        ext_catalog = JSON.parse(File.read(@extended_catalog_path))
        CSV.open(File.join(@run_dir, @rnm_dirname, 'udcons.csv'), 'w') do |csv|
          ext_catalog.each do |key, v|
            if key != 'WIRES'
              csv << ["<#{key}>"]
              if ext_catalog[key].is_a?(Hash) # defining the section under consideration is an Hash or an Array
                if key == 'OTHERS'
                  ext_catalog[key]['UTM Zone'] = utm_zone.to_s
                end
                ext_catalog[key].each do |k, v|
                  row = []
                  row.push(k) # title of the array
                  matrix_processing(csv, ext_catalog[key][k], v, row, key, ext_catalog['WIRES'], k)
                end
              else
                if ext_catalog[key].empty?
                  csv << ['END']
                else
                  for i in 0..ext_catalog[key].length - 1
                    row = []
                    if ext_catalog[key][i].is_a?(Hash)
                      ext_catalog[key][i].each do |k, v|
                        row.push(k)  # title of the array
                        matrix_processing(csv, ext_catalog[key][i][k], v, row, key, ext_catalog['WIRES'], k)
                        if key == 'LINES' || key == 'SUBSTATIONS AND DISTRIBUTION TRANSFORMERS' || key == 'CAPACITORS'
                          csv << ['END']
                        end
                      end
                    end
                    end
                end
              end
              csv << ["</#{key}>"]
            end
          end
        end
      end
    end
  end
end

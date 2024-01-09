# *********************************************************************************
# URBANopt™, Copyright © Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-rnm-us-gem/blob/develop/LICENSE.md
# *********************************************************************************

require 'urbanopt/rnm/logger'
require 'json'
require 'csv'
require 'set'
require 'matrix'

module URBANopt
  module RNM
    # creating a class which is able to convert the line-geometry information for each power line and the
    # conductors information, into power lines information, obtaining their impedances and capacitance
    # applying carsons equations
    class CarsonEq
      def initialize(hash)
        @power_line = hash
      end

      # method to place the new parameters created in the right position in the final RNM-US catalog
      def insert_field(key, fields, proximity = :before)
        @power_line = @power_line.to_a.insert(@power_line.keys.index(key) + (proximity == :after ? 1 : 0), fields.first).to_h
      end

      # method to convert initial SI units in the ext catalog into Imperial units used by the Carson equation
      # create the one from ft to m
      def si_to_imperial_units(quantity, unit_input, unit_output)
        if unit_output == 'ft' && unit_input == 'mm'
          return quantity * 0.003281
        elsif unit_output == 'ft' && unit_input == 'm'
          quantity / 0.3048
          return quantity / 0.3048
        elsif unit_output == 'mi' && unit_input == 'km'
          return quantity / 1.6093
        elsif unit_output == '1/mi' && unit_input == '1/km'
          return quantity * 1.6093
        elsif unit_output == '1/ft' && unit_input == '1/m'
          return quantity * 0.3048
        end
      end

      # method to convert the results in Imperial units into SI units used by the RNM-US model
      # create the one from ft to m
      def imperial_to_si_units(quantity, unit_input, unit_output)
        if unit_output == 'ft'
          return quantity * 0.3048
        elsif unit_output == 'mi' && unit_input == 'km'
          return quantity * 1.60934
        elsif unit_output == '1/km' && unit_input == '1/mi'
          return (quantity / 1.60934)
        end
      end

      def get_sequence_impedance_matrix(phase_impedance_matrix)
        a = Complex(Math.cos(Math::PI * 2 / 3), Math.sin(Math::PI * 2 / 3))
        a_matrix = Matrix[[1, 1, 1], [1, a**2, a], [1, a, a**2]]
        a_matrix_inv = a_matrix.inverse
        half = phase_impedance_matrix * a_matrix
        final_matrix = a_matrix_inv * half
        return final_matrix
      end

      # method which applies the kron reduction to reduce the primitive impedance matrix by one dimension
      def kron_reduction(primitive_impedance_matrix, n_concentric_neutrals)
        if n_concentric_neutrals == 0
          neutrals = primitive_impedance_matrix.length - 1 # position of the neutral in primitive_imp_matrix
          dim_neutrals = primitive_impedance_matrix.length - neutrals
        else
          neutrals = primitive_impedance_matrix.length - n_concentric_neutrals # position of the neutral in primitive_imp_matrix
          dim_neutrals = n_concentric_neutrals
        end
        dim_phase = primitive_impedance_matrix.length - dim_neutrals
        zij = Array.new(dim_phase) { Array.new(dim_phase) }
        for i in 0..dim_phase - 1
          for j in 0..dim_phase - 1
            j < dim_phase && i < dim_phase
            zij[i][j] = primitive_impedance_matrix[i][j]
          end
        end
        znn = Array.new(dim_neutrals) { Array.new(dim_neutrals) }
        for i in 0..znn.length - 1
          for j in 0..znn.length - 1
            znn[i][j] = primitive_impedance_matrix[neutrals + i][neutrals + j] # neutrals e l indice del neutro
          end
        end
        zin = Array.new(dim_phase) { Array.new(dim_neutrals) } # z[i][n]
        for i in 0..dim_phase - 1
          for j in 0..dim_neutrals - 1
            i < dim_phase
            zin[i][j] = primitive_impedance_matrix[i][neutrals + j]
          end
        end
        znj = Array.new(dim_neutrals) { Array.new(dim_phase) } # z[n][j]
        for i in 0..dim_neutrals - 1
          for j in 0..dim_phase - 1
            j < dim_phase
            znj[i][j] = primitive_impedance_matrix[i + neutrals][j]
          end
        end

        half = Matrix[*znn].inverse * Matrix[*znj] # first step to obtain the first matrix
        seq = Matrix[*zij] - (Matrix[*zin] * half)
        return seq
      end

      # methods to apply the modified Carson equation to either the diagonal components of the primitive impedance matrix or to the other components
      def carson_equation_self(ri, gmri)
        # Carson's equation for self impedance
        return Complex(ri + 0.0953, 0.12134 * (Math.log(1.0 / gmri) + 7.93402)) # GMR e il geometric mean radius del conduttore
      end

      def carson_equation(dij)
        # """Carson's equation for mutual impedance
        if dij != 0
          return Complex(0.09530, 0.12134 * (Math.log(1.0 / dij) + 7.93402))
        end
      end

      # method applying a similar concept of the Carson equation, but for obtaining the primitive potential coeff matrix
      # for obtaining the lines capacitance
      def get_primitive_potential_coeff_matrix(diamaters, images_matrix, dist_matrix)
        n_rows = images_matrix.length
        n_cols = images_matrix.length
        primitive_potential_coeff_matrix = Array.new(n_rows) { Array.new(n_rows) }
        for i in 0..n_rows - 1
          for j in 0..n_cols - 1
            if i == j
              primitive_potential_coeff_matrix[i][j] = 11.17689 * Math.log(images_matrix[i][j] / (diamaters[i] / 2)) # assuming relative permittivity of air of 1.4240 x 10 mF/mile
            else
              primitive_potential_coeff_matrix[i][j] = 11.17689 * Math.log(images_matrix[i][j] / dist_matrix[i][j]) # assuming relative permittivity of air of 1.4240 x 10 mF/mile
            end
          end
        end
        return primitive_potential_coeff_matrix
      end

      # method for obtaining the primitive impedance matrix
      def get_primitive_impedance_matrix(dist_matrix, gmr_list, r_list)
        '''Get primitive impedance matrix from distance matrix between the wires, GMR list, and resistance list.'''
        n_rows = dist_matrix.length
        n_cols = dist_matrix.length
        primitive_impedance_matrix = Array.new(n_rows) { Array.new(n_rows) }
        for i in 0..n_rows - 1
          for j in 0..n_cols - 1
            if i == j
              primitive_impedance_matrix[i][j] = carson_equation_self(r_list[i], gmr_list[i])
            else
              primitive_impedance_matrix[i][j] = carson_equation(dist_matrix[i][j])
            end
          end
        end
        return primitive_impedance_matrix
      end

      # method to obtain the lines capacitance
      def get_capacitance(wire_list)
        nphases = wire_list.height.length
        conc_neutrals = wire_list.r_neutral.length
        distance_matrix = Array.new(nphases) { Array.new(nphases) }
        distance_matrix_feet = Array.new(nphases) { Array.new(nphases) }
        image_matrix = Array.new(nphases) { Array.new(nphases) }
        image_matrix_ft = Array.new(nphases) { Array.new(nphases) }
        diameters_conductors_ft = []
        w = 2 * Math::PI * 60
        for i in 0..nphases - 1
          diameters_conductors_ft[i] = si_to_imperial_units(wire_list.diameter[i], 'mm', 'ft')
          for j in 0..nphases - 1
            distance_matrix[i][j] = (((wire_list.x[i] - wire_list.x[j])**2 + (wire_list.height[i] - wire_list.height[j])**2)**0.5).to_f.round(5) # ((i - j).abs() * 0.6) #60cm apart one above the other or side by side
            image_matrix[i][j] = (((wire_list.x[i] - wire_list.x[j])**2 + (wire_list.height[i] - -wire_list.height[j])**2)**0.5).to_f.round(5) # computing matrix with distances among images of the cables referred to the ground
            distance_matrix_feet[i][j] = si_to_imperial_units(distance_matrix[i][j], 'm', 'ft')
            image_matrix_ft[i][j] = si_to_imperial_units(image_matrix[i][j], 'm', 'ft')
          end
        end
        if conc_neutrals == 0 # meaning that we are NOT considering concentric neutrals
          primitive_potential_coeff = get_primitive_potential_coeff_matrix(diameters_conductors_ft, image_matrix_ft, distance_matrix_feet)
          if primitive_potential_coeff.length != 3
            reduced_potential_coeff = kron_reduction(primitive_potential_coeff, conc_neutrals)
          else
            reduced_potential_coeff = Matrix[*primitive_potential_coeff]
          end
          capacitance_matrix = reduced_potential_coeff.inverse # obtaining the capacitance matrix in micro Farad
          for i in 0..capacitance_matrix.column_size - 1
            for j in 0..capacitance_matrix.column_size - 1
              capacitance_matrix[i, j] = Complex(0, capacitance_matrix[i, j] * w)
            end
          end
          if capacitance_matrix.column_size > 1
            seq_capacitance = Array.new(3) { Array.new(3) }
            seq_admittance_ft = get_sequence_impedance_matrix(capacitance_matrix)
            for i in 0..seq_admittance_ft.column_size - 1
              for j in 0..seq_admittance_ft.column_size - 1
                seq_capacitance[i][j] = imperial_to_si_units((seq_admittance_ft[i, j] / w) * 1000, '1/mi', '1/km') # to be provided in nF
              end
            end
            capacitance = { 'Capacitance(nF/km)' => seq_capacitance[1][1].imag, 'C0 (nF/km)' => seq_capacitance[0][0].imag }
          else
            seq_capacitance = imperial_to_si_units((capacitance_matrix[0, 0] / w) * 1000, '1/mi', '1/km')
            capacitance = { 'Capacitance(nF/km)' => seq_capacitance.imag, 'C0 (nF/km)' => seq_capacitance.imag }
          end
        else # now computing the capacitance for UG concentric neutral power lines
          material_permettivity = 2.3 # assuming using the minimum permittivity value for "cross-linked polyethlyene", as the insulation material
          free_space_permittivity = 0.0142 # in microfaraday/mile
          radius = (wire_list.outside_diamater_neutral[0] - wire_list.diameter_n_strand[0]) / 2 # in mm
          radius_ft = si_to_imperial_units(radius, 'mm', 'ft')
          radius_neutral_ft = si_to_imperial_units(wire_list.diameter_n_strand[0] / 2, 'mm', 'ft')
          radius_conductor_ft = diameters_conductors_ft[0] / 2
          numerator = 2 * Math::PI * material_permettivity * free_space_permittivity
          denominator = (Math.log(radius_ft / radius_conductor_ft) - ((1 / wire_list.neutral_strands[0]) * Math.log((wire_list.neutral_strands[0] * radius_neutral_ft) / radius_ft)))
          (numerator / denominator) * 1000
          seq_capacitance = imperial_to_si_units((numerator / denominator) * 1000, '1/mi', '1/km')
          capacitance = { 'Capacitance(nF/km)' => seq_capacitance, 'C0 (nF/km)' => seq_capacitance }
        end
        return capacitance
      end

      # method to obtain the line sequence impedances
      def get_sequence_impedances(wire_list)
        '''Get sequence impedances Z0, Z+, Z- from distance matrix between the wires, GMR list, and resistance list.'''
        nphases = wire_list.height.length
        conc_neutrals = wire_list.r_neutral.length
        distance_matrix = Array.new(nphases + conc_neutrals) { Array.new(nphases + conc_neutrals) }
        distance_matrix_feet = Array.new(nphases + conc_neutrals) { Array.new(nphases + conc_neutrals) }
        gmr_ft = []
        resistance_mi = []
        gmr_neutral = []
        for i in 0..nphases - 1
          for j in 0..nphases - 1
            distance_matrix[i][j] = (((wire_list.x[i] - wire_list.x[j])**2 + (wire_list.height[i] - wire_list.height[j])**2)**0.5).to_f.round(5) # ((i - j).abs() * 0.6) #60cm apart one above the other or side by side
          end
        end
        if !wire_list.r_neutral[0].nil? # computing parameters for concentric neutrals wires
          for j in 0..conc_neutrals - 1
            radius = (wire_list.outside_diamater_neutral[j] - wire_list.diameter_n_strand[j]) / 2
            wire_list.gmr.push(wire_list.gmr_neutral[j] * wire_list.neutral_strands[j] * (radius**(wire_list.neutral_strands[j] - 1))**(1 / wire_list.neutral_strands[j]))
            wire_list.r.push(wire_list.r_neutral[j] / wire_list.neutral_strands[j])
            for k in 0..conc_neutrals - 1
              distance_matrix[conc_neutrals + j][conc_neutrals + k] = distance_matrix[j][k]
              if j == k
                distance_matrix[j + conc_neutrals][k] = radius / 1000 # converting from mm to m
                distance_matrix[j][k + conc_neutrals] = radius / 1000
              # As per Example 4.2 of Kersting. phase-neutral = phase-phase distance for different cables
              else
                distance_matrix[j + conc_neutrals][k] = distance_matrix[j][k]
                distance_matrix[j][k + conc_neutrals] = distance_matrix[j][k]
              end
            end
          end
        end
        for i in 0..distance_matrix.length - 1
          gmr_ft[i] = si_to_imperial_units(wire_list.gmr[i], 'mm', 'ft') # in ft
          resistance_mi[i] = si_to_imperial_units(wire_list.r[i], '1/km', '1/mi') # in miles verify if it was provided in miles
          for j in 0..distance_matrix.length - 1
            distance_matrix_feet[i][j] = si_to_imperial_units(distance_matrix[i][j], 'm', 'ft')
          end
        end
        primitive = get_primitive_impedance_matrix(distance_matrix_feet, gmr_ft, resistance_mi)
        if primitive.length != 3 # not for V-phase lines, I keep these lines as a 3x3 Matrix, without executing Kron Reduction
          phase = kron_reduction(primitive, conc_neutrals) # passing number of concentric neutrals if any
        else
          phase = Matrix[*primitive] # still treated as a 3x3 Matrix
        end
        if phase.column_size != 1 # if single-phase lines the sequence impedance value is already obtained
          seq_new = Array.new(3) { Array.new(3) }
          seq = get_sequence_impedance_matrix(phase)
          for i in 0..seq.column_size - 1
            for j in 0..seq.column_size - 1
              seq_new[i][j] = imperial_to_si_units(seq[i, j], '1/mi', '1/km')
            end
          end
          impedances = { 'Resistance(ohms/km)' => seq_new[1][1].real, 'Ind. Reactance(ohms/km)' => seq_new[1][1].imag, 'R0 (ohms/km)' => seq_new[0][0].real, 'X0 (ohms/km)' => seq_new[0][0].imag }
        else
          seq_new = imperial_to_si_units(phase[0, 0], '1/mi', '1/km')
          impedances = { 'Resistance(ohms/km)' => seq_new.real, 'Ind. Reactance(ohms/km)' => seq_new.imag, 'R0 (ohms/km)' => seq_new.real, 'X0 (ohms/km)' => seq_new.imag }
        end
        return impedances
      end

      # method that starting from each line geometry finds the parameters of each wire forming that power line
      def creation(wires)
        seq_impedances = []
        wire_list = []
        hash = {}
        jj = 0
        wire_list = URBANopt::RNM::WiresExtendedCatalog.new
        # puts wire_list
        for j in 0..@power_line['Line geometry'].length - 1
          for k in 0..wires['WIRES CATALOG'].length - 1
            if @power_line['Line geometry'][j]['wire'] == wires['WIRES CATALOG'][k]['nameclass']
              wire_list.name.push(wires['WIRES CATALOG'][k]['nameclass'])
              wire_list.diameter.push(wires['WIRES CATALOG'][k]['diameter (mm)'])
              wire_list.r.push(wires['WIRES CATALOG'][k]['resistance (ohm/km)'])
              wire_list.gmr.push(wires['WIRES CATALOG'][k]['gmr (mm)'])
              wire_list.ampacity.push(wires['WIRES CATALOG'][k]['ampacity (A)'])
              wire_list.type.push(wires['WIRES CATALOG'][k]['type'])
              if wires['WIRES CATALOG'][k].include? 'resistance neutral (ohm/km)'
                wire_list.r_neutral.push(wires['WIRES CATALOG'][k]['resistance neutral (ohm/km)'])
                wire_list.gmr_neutral.push(wires['WIRES CATALOG'][k]['gmr neutral (mm)'])
                wire_list.neutral_strands.push(wires['WIRES CATALOG'][k]['# concentric neutral strands'])
                wire_list.diameter_n_strand.push(wires['WIRES CATALOG'][k]['concentric diameter neutral strand (mm)'])
                wire_list.outside_diamater_neutral.push(wires['WIRES CATALOG'][k]['concentric neutral outside diameter (mm)'])
              end
            end
          end
          if @power_line['Line geometry'][j]['phase'] != 'N' # && @power_line["Current(A) "] != nil
            line_current = wire_list.ampacity[j]
          end
          wire_list.x.push(@power_line['Line geometry'][j]['x (m)'])
          wire_list.height.push(@power_line['Line geometry'][j]['height (m)'])
        end
        capacitances = get_capacitance(wire_list)
        impedances = get_sequence_impedances(wire_list)
        # electric_parameters = impedances.merge(capacitances)
        @power_line.delete('Line geometry')
        cont = 0
        pair = []
        key = 0
        # organizing the impedances and capacitance values found to be placed in the right order in the RNM-US catalog
        impedances.each do |k, v| # place the new fields in the right positions
          pair[cont] = { k => v }
          if cont < 2
            field =
              if  cont == 0
                insert_field('Nphases', pair[cont], :after)
              else
                insert_field(key, pair[cont], :after)
              end
            key = k
          else
            if cont == 2
              insert_field(key, { 'Current(A)' => line_current }, :after)
              insert_field('Repair time maximum (hours)', pair[cont], :after)
            else
              insert_field(key, pair[cont], :after)
            end
            key = k
          end
          cont += 1
        end
        cont = 0
        capacitances.each do |k, v|
          if cont == 0
            insert_field('Ind. Reactance(ohms/km)', { k => v }, :after)
          else
            insert_field('X0 (ohms/km)', { k => v }, :after)
          end
          cont += 1
        end
        return @power_line
      end
    end
  end
end

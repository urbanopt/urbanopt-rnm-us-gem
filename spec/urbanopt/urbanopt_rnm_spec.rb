# *********************************************************************************
# URBANopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC, and other
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

require 'fileutils'

require_relative '../spec_helper'

RSpec.describe URBANopt::RNM do

  it 'has a version number' do
    expect(URBANopt::RNM::VERSION).not_to be nil
  end

  it 'has a logger' do
    expect(URBANopt::RNM.logger).not_to be nil
    current_level = URBANopt::RNM.logger.level
    URBANopt::RNM.logger.level = Logger::DEBUG
    expect(URBANopt::RNM.logger.level).to eq Logger::DEBUG
    URBANopt::RNM.logger.level = current_level
  end

  context 'run simulation' do
    before(:all) do
      @root_dir = File.join(File.dirname(__FILE__), '..', 'test', 'example_project')
      @run_dir = File.join(@root_dir, 'run', 'baseline_scenario')
      @feature_file_path = File.join(@root_dir,  'example_project_combined1.json')
      @reopt = false
      @extended_catalog_path = File.join(File.dirname(__FILE__), '..', '..','catalogs',  'extended_catalog.json')
      @average_peak_catalog_path = File.join(File.dirname(__FILE__), '..', '..','catalogs',  'average_peak_per_building_type.json')
      @name = 'baseline_scenario' 
      
      if !File.exists?(File.join(File.dirname(__FILE__), '..', 'test'))
        FileUtils.mkdir_p(File.join(File.dirname(__FILE__), '..', 'test'))
      end
      
      FileUtils.cp_r(File.join(File.dirname(__FILE__), '..', 'files', 'example_project'), File.join(File.dirname(__FILE__), '..', 'test'))
      @runner = URBANopt::RNM::Runner.new(@name, @root_dir, @run_dir, @feature_file_path, @reopt, @extended_catalog_path, @average_peak_catalog_path)
    end
    
    it 'creates the rnm-us input files' do

      # check that example project directory was created
      expect(File.exists?(@root_dir)).to be true
      
      # create sim files
      @runner.create_simulation_files()

      # check that input files were created
      expect(File.exists?(File.join(@run_dir, 'rnm-us'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'customers.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'customers_ext.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'streetmapAS.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'cust_profile_p.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'cust_profile_q.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'cust_profile_q_estendido.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'cust_profile_p_estendido.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'ficheros_entrada.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'ficheros_entrada_inc.txt'))).to be true


    end

    #it 'runs and gets results' do
      # depends on files created in previous test
     # @runner.run()
     # @runner.get_results()
      # begin
      #   @runner.get_results()
      # rescue
        # test download with a valid simulation (just for quick testing)
        # @runner.download_results('344c0187-47ae-4fff-9bb1-a98030ca255b')
      # end
    #end
  end
  #modify this according to reopt
  context 'run simulation' do
    before(:all) do
      @root_dir = File.join(File.dirname(__FILE__), '..', 'reopt_test', 'example_project')
      @run_dir = File.join(@root_dir, 'run', 'baseline_scenario')
      @feature_file_path = File.join(@root_dir,  'example_project_streets.json')
      @name = 'baseline_scenario' 
      @reopt = true
      @extended_catalog_path = File.join(File.dirname(__FILE__), '..', '..','catalogs',  'extended_catalog.json')
      @average_peak_catalog_path = File.join(File.dirname(__FILE__), '..', '..','catalogs',  'average_peak_per_building_type.json')
      
      if !File.exists?(File.join(File.dirname(__FILE__), '..', 'reopt_test'))
        FileUtils.mkdir_p(File.join(File.dirname(__FILE__), '..', 'reopt_test'))
      end
      
      FileUtils.cp_r(File.join(File.dirname(__FILE__), '..', 'files', 'example_project'), File.join(File.dirname(__FILE__), '..', 'reopt_test'))
      @runner = URBANopt::RNM::Runner.new(@name, @root_dir, @run_dir, @feature_file_path)
    end
    
    it 'creates the rnm-us input files' do

      # check that example project directory was created
      expect(File.exists?(@root_dir)).to be true
      
      # create sim files
      @runner.create_simulation_files()

      # check that input files were created
      expect(File.exists?(File.join(@run_dir, 'rnm-us'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'customers.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'customers_ext.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'streetmapAS.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'cust_profile_p.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'cust_profile_q.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'cust_profile_q_estendido.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'cust_profile_p_estendido.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'ficheros_entrada.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'ficheros_entrada_inc.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'gen_profile_p_extendido.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'gen_profile_q_extendido.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'gen_profile_q.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'gen_profile_p.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'generators.txt'))).to be true
      expect(File.exists?(File.join(@run_dir, 'rnm-us', 'ficheros_entrada_inc.txt'))).to be true

    end

    #it 'runs and gets results' do
      # depends on files created in previous test
     # @runner.run()
      #@runner.get_results()
      # begin
      #   @runner.get_results()
      # rescue
        # test download with a valid simulation (just for quick testing)
        # @runner.download_results('344c0187-47ae-4fff-9bb1-a98030ca255b')
      # end
  end
end

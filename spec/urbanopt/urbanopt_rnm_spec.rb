# *********************************************************************************
# URBANopt™, Copyright © Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-rnm-us-gem/blob/develop/LICENSE.md
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

  context 'run basic simulation' do
    before(:all) do
      @root_dir = File.join(File.dirname(__FILE__), '..', 'test', 'example_project')
      @run_dir = File.join(@root_dir, 'run', 'baseline_scenario')
      @rnm_dir = File.join(@run_dir, 'rnm-us')
      @results_dir = File.join(@rnm_dir, 'results')
      @feature_file_path = File.join(@root_dir, 'example_project_with_network_and_streets.json')
      @scenario_csv_path = File.join(@root_dir, 'baseline_scenario.csv')
      @reopt = false
      @extended_catalog_path = File.join(File.dirname(__FILE__), '..', '..', 'catalogs',  'extended_catalog.json')
      @average_peak_catalog_path = File.join(File.dirname(__FILE__), '..', '..', 'catalogs', 'average_peak_per_building_type.json')
      @name = 'baseline_scenario'
      @opendss_catalog = true

      if !File.exist?(File.join(File.dirname(__FILE__), '..', 'test'))
        FileUtils.mkdir_p(File.join(File.dirname(__FILE__), '..', 'test'))
      end

      FileUtils.cp_r(File.join(File.dirname(__FILE__), '..', 'files', 'example_project'), File.join(File.dirname(__FILE__), '..', 'test'))
      @runner = URBANopt::RNM::Runner.new(@name, @run_dir, @scenario_csv_path, @feature_file_path, extended_catalog_path: @extended_catalog_path, average_peak_catalog_path: @average_peak_catalog_path, reopt: @reopt, opendss_catalog: @opendss_catalog)
    end

    it 'creates the rnm-us input files' do
      # check that example project directory was created
      expect(File.exist?(@root_dir)).to be true

      # create sim files
      @runner.create_simulation_files

      # check that input files were created
      expect(File.exist?(File.join(@run_dir, 'rnm-us'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'customers.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'customers_ext.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'streetmapAS.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'cust_profile_p.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'cust_profile_q.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'cust_profile_q_extendido.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'cust_profile_p_extendido.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'ficheros_entrada.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'ficheros_entrada_inc.txt'))).to be true

      # check that opendss catalog was created (default is to create it)
      expect(File.exist?(File.join(@run_dir, 'opendss_catalog.json'))).to be true
    end

    it 'uses default field values when none are specified in feature file' do
      @feature_file_path2 = File.join(@root_dir, 'example_project_streets_missingfields.json')

      # also attempt to use defaults
      @runner2 = URBANopt::RNM::Runner.new(@name, @run_dir, @scenario_csv_path, @feature_file_path2, reopt: @reopt)
      expect {  @runner2.create_simulation_files }.to output(a_string_including("RNM-US gem WARNING: field ['project']['only_lv_consumers'] not specified in Feature File...using default value of")).to_stdout
      expect {  @runner2.create_simulation_files }.to output(a_string_including("RNM-US gem WARNING: field ['project']['underground_cables_ratio'] not specified in Feature File...using default value of")).to_stdout
      expect {  @runner2.create_simulation_files }.to output(a_string_including("RNM-US gem WARNING: field ['project']['max_number_of_lv_nodes_per_building'] not specified in Feature File...using default value of")).to_stdout
    end

    it 'zips inputs, runs simulation and gets results' do
      @runner.run
      expect(File.exist?(File.join(@rnm_dir, 'inputs.zip')))
      expect(!File.exist?(File.join(@rnm_dir, 'udcons.csv'))) # this should have gotten cleaned up
      expect(Dir.exist?(File.join(@results_dir)))
      expect(File.exist?(File.join(@results_dir, 'Summary', 'Summary.json')))
    end

    it 'post processes results' do
      @runner.post_process
      expect(File.exist?(File.join(@run_dir, 'scenario_report_rnm.json')))
      expect(File.exist?(File.join(@run_dir, 'feature_file_rnm.json')))
    end
  end

  # modify this according to reopt
  context 'run REopt simulation' do
    before(:all) do
      @root_dir = File.join(File.dirname(__FILE__), '..', 'test_reopt', 'example_project')
      @run_dir = File.join(@root_dir, 'run', 'reopt_scenario')
      @rnm_dir = File.join(@run_dir, 'rnm-us')
      @results_dir = File.join(@rnm_dir, 'results')
      @feature_file_path = File.join(@root_dir, 'example_project_with_network_and_streets.json')
      @scenario_csv_path = File.join(@root_dir, 'REopt_scenario.csv')
      @name = 'reopt_scenario'
      @reopt = true
      @extended_catalog_path = File.join(File.dirname(__FILE__), '..', '..', 'catalogs',  'extended_catalog.json')
      @average_peak_catalog_path = File.join(File.dirname(__FILE__), '..', '..', 'catalogs', 'average_peak_per_building_type.json')
      @opendss_catalog = false

      if !File.exist?(File.join(File.dirname(__FILE__), '..', 'test_reopt'))
        FileUtils.mkdir_p(File.join(File.dirname(__FILE__), '..', 'test_reopt'))
      end

      FileUtils.cp_r(File.join(File.dirname(__FILE__), '..', 'files', 'example_project'), File.join(File.dirname(__FILE__), '..', 'test_reopt'))
      @runner = URBANopt::RNM::Runner.new(@name, @run_dir, @scenario_csv_path, @feature_file_path, extended_catalog_path: @extended_catalog_path, average_peak_catalog_path: @average_peak_catalog_path, reopt: @reopt, opendss_catalog: @opendss_catalog)
    end

    it 'creates the rnm-us input files' do
      # check that example project directory was created
      expect(File.exist?(@root_dir)).to be true

      # create sim files
      @runner.create_simulation_files

      # check that input files were created
      expect(File.exist?(File.join(@run_dir, 'rnm-us'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'customers.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'customers_ext.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'streetmapAS.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'cust_profile_p.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'cust_profile_q.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'cust_profile_q_extendido.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'cust_profile_p_extendido.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'ficheros_entrada.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'ficheros_entrada_inc.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'gen_profile_p_extendido.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'gen_profile_q_extendido.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'gen_profile_q.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'gen_profile_p.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'generators.txt'))).to be true
      expect(File.exist?(File.join(@run_dir, 'rnm-us', 'ficheros_entrada_inc.txt'))).to be true

      # check that opendss catalog was not created
      # expect(File.exist?(File.join(@run_dir, 'opendss_catalog.json'))).to be false
    end

    it 'zips inputs, runs simulation and gets results' do
      @runner.run
      expect(File.exist?(File.join(@rnm_dir, 'inputs.zip')))
      expect(!File.exist?(File.join(@rnm_dir, 'udcons.csv'))) # this should have gotten cleaned up
      expect(Dir.exist?(File.join(@results_dir)))
      expect(File.exist?(File.join(@results_dir, 'Summary', 'Summary.json')))
    end

    it 'post processes simulation results' do
      @runner.post_process
      expect(File.exist?(File.join(@run_dir, 'scenario_report_rnm.json')))
      expect(File.exist?(File.join(@run_dir, 'feature_file_rnm.json')))
    end
  end

  context 'save opendss catalog' do
    it 'saves the opendss catalog' do
      @extended_catalog_path = File.join(File.dirname(__FILE__), '..', '..', 'catalogs', 'extended_catalog.json')
      @save_path = File.join(File.dirname(__FILE__), '..', 'test_opendss_catalog.json')

      if File.exist?(@save_path)
        FileUtils.rm_r(@save_path)
      end

      # create catalog and save to specified path
      @opendss_catalog = URBANopt::RNM::ConversionToOpendssCatalog.new(@extended_catalog_path)
      @opendss_catalog.create_catalog(@save_path)
      expect(File.exist?(@save_path)).to be true
    end
  end
end

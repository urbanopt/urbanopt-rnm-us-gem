# *********************************************************************************
# URBANopt™, Copyright © Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-rnm-us-gem/blob/develop/LICENSE.md
# *********************************************************************************

require 'csv'
require 'urbanopt/rnm/logger'

module URBANopt
  module RNM
    # Runner class handles running a scenario through RNM-US and retrieving results
    class Runner
      ##
      # Initialize Runner attributes: +name+ , +root directory+ , +run directory+ and +feature_file_path+
      ##
      # [parameters:]
      # * +name+ - _String_ - Human readable scenario name.
      # * +run_dir+ - _String_ - Full path to directory for simulation of this scenario
      # * +feature_file_path+ - _String_ - Full path to GeoJSON feature file containing features and streets for simulation.
      # * +scenario_csv_path+ - _String_ - Full path to the Scenario CSV file containing list of features to run for this scenario.
      # * +extended_catalog_path+ - _String_ - Full path to the extended catalog
      # * +average_peak_catalog_path+ - _String_ - Full path to average peak catalog
      # * +reopt+ - _Boolean_ - Use REopt results to generate inputs? Defaults to false
      # * +opendss_catalog+ - _Boolean_ - Generate OpenDSS catalog? Defaults to true
      def initialize(name, run_dir, scenario_csv_path, feature_file_path, extended_catalog_path: nil, average_peak_catalog_path: nil, reopt: false, opendss_catalog: true)
        @name = name
        # these are all absolute paths
        @run_dir = run_dir
        @feature_file_path = feature_file_path
        @scenario_csv_path = scenario_csv_path
        @api_client = nil
        @rnm_dirname = 'rnm-us'
        @rnm_dir = File.join(@run_dir, @rnm_dirname)
        @reopt = reopt
        @extended_catalog_path = extended_catalog_path
        @average_peak_catalog_path = average_peak_catalog_path
        @opendss_catalog = opendss_catalog
        @results = []

        # load feature file
        @feature_file = JSON.parse(File.read(@feature_file_path))

        # process CSV to get feature IDs only
        @scenario_features = get_scenario_features

        # set default catalog paths if they are nil
        if @extended_catalog_path.nil?
          @extended_catalog_path = File.join(File.dirname(__FILE__), '..', '..', '..', 'catalogs', 'extended_catalog.json')
        end
        if @average_peak_catalog_path.nil?
          @average_peak_catalog_path = File.join(File.dirname(__FILE__), '..', '..', '..', 'catalogs', 'average_peak_per_building_type.json')
        end

        # initialize @@logger
        @@logger ||= URBANopt::RNM.logger

        # puts "REOPT: #{@reopt}, OPENDSS_CATALOG: #{@opendss_catalog}"
      end

      ##
      # Name of the Scenario.
      attr_reader :name #:nodoc:

      ##
      # Directory to run this Scenario.
      attr_reader :run_dir #:nodoc:

      ##
      # Feature file path associated with this Scenario.
      attr_reader :feature_file_path #:nodoc:

      ##
      # Scenario CSV path associated with this Scenario.
      attr_reader :scenario_csv_path #:nodoc:

      ##
      # Feature file path associated with this Scenario.
      attr_reader :reopt #:nodoc:

      ##
      # Feature file path associated with this Scenario.
      attr_reader :average_peak_catalog_path #:nodoc:

      ##
      # Feature file path associated with this Scenario.
      attr_reader :extended_catalog_path #:nodoc:

      ##
      # Get Scenario Features
      ##
      def get_scenario_features
        @num_header_rows = 1
        features = []
        CSV.foreach(@scenario_csv_path, headers: true) do |row|
          break if row[0].nil?

          # gets +feature_id+ and append to list
          features << row[0].chomp
        end
        return features
      end

      ##
      # Create RNM-US Input Files
      ##
      def create_simulation_files
        # generate RNM-US input files
        in_files = URBANopt::RNM::InputFiles.new(@run_dir, @scenario_features, @feature_file, @extended_catalog_path, @average_peak_catalog_path, reopt: @reopt, opendss_catalog: @opendss_catalog)
        in_files.create
      end

      ##
      # Run RNM-US Simulation (via RNM-US api) and get results
      ##
      # [parameters:]
      # * +use_local+ - _Boolean_ - Flag to use localhost API vs production API
      def run(use_local = false)
        # start client
        @api_client = URBANopt::RNM::ApiClient.new(@name, @rnm_dir, use_localhost = use_local, reopt = @reopt)
        @api_client.zip_input_files
        @api_client.submit_simulation
        @results = @api_client.get_results
      end

      ##
      # Download results for a simulation separately
      ##
      def download_results(sim_id = nil)
        @api_client.download_results(sim_id)
      end

      ##
      # Post-process results back into scenario json file
      ##
      def post_process
        @rnm_pp = URBANopt::RNM::PostProcessor.new(@results, @run_dir, @feature_file)
        @rnm_pp.post_process
      end


      ##
      # Run OpenDSS validation
      ##
      def run_validation
        # generate RNM-US input files
        validation = URBANopt::RNM::Validation.new(@run_dir)
        validation.run_validation
      end
    end
  end
end

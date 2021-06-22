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
      # * +root_dir+ - _String_ - Full path to root directory for the scenario, contains Gemfile describing dependencies.
      # * +run_dir+ - _String_ - Full path to directory for simulation of this scenario
      # * +feature_file_path+ - _String_ - Full path to GeoJSON feature file containing features and streets for simulation.
      # * +extended_catalog_path+ - _String_ - Full path to the extended catalog
      # * +average_peak_catalog_path+ - _String_ - Full path to average peak catalog
      # * +reopt+ - _Boolean_ - Use REopt results to generate inputs? Defaults to false
      # * +opendss_catalog+ - _Boolean_ - Generate OpenDSS catalog? Defaults to true
      def initialize(name, root_dir, run_dir, feature_file_path, extended_catalog_path, average_peak_catalog_path, reopt:false, opendss_catalog:true)
        @name = name
        # these are all absolute paths
        @root_dir = root_dir
        @run_dir = run_dir
        @feature_file_path = feature_file_path
        @api_client = nil
        @rnm_dirname = 'rnm-us'
        @rnm_dir = File.join(@run_dir, @rnm_dirname)
        @reopt = reopt
        @extended_catalog_path = extended_catalog_path
        @average_peak_catalog_path = average_peak_catalog_path
        @opendss_catalog = opendss_catalog
        # initialize @@logger
        @@logger ||= URBANopt::RNM.logger
      
      end

      ##
      # Name of the Scenario.
      attr_reader :name #:nodoc:

      ##
      # Root directory containing Gemfile.
      attr_reader :root_dir #:nodoc:

      ##
      # Directory to run this Scenario.
      attr_reader :run_dir #:nodoc:

      ##
      # Feature file path associated with this Scenario.
      attr_reader :feature_file_path #:nodoc:

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
      # Create RNM-US Input Files
      ##
      def create_simulation_files()
        
        # generate RNM-US input files
        in_files = URBANopt::RNM::InputFiles.new(@run_dir, @feature_file_path, @extended_catalog_path, @average_peak_catalog_path, reopt:@reopt, opendss_catalog:@opendss_catalog)
        in_files.create()

      end

      ##
      # Run RNM-US Simulation (via RNM-US api)
      ##
      def run()
        # start client
        # TODO: fix this!
        @api_client = URBANopt::RNM::ApiClient.new(@name, @rnm_dir, true)
        @api_client.submit_simulation()
        
      end
      
      ##
      # Retrieve RNM-US results (via RNM-US api)
      ##
      def get_results()
        # ping for results and download when ready
        @api_client.get_results()
      end

      ## 
      # Download results for a simulation separately
      ##
      def download_results(sim_id=nil)
        @api_client.download_results(sim_id)
      end
    end
  end
end

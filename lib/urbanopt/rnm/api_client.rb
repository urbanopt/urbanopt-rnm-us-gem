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

require 'faraday'
require 'json'
require 'urbanopt/rnm/logger'
require 'zip'

module URBANopt
  module RNM
  	# Client to interface with the RNM-US API
  	class ApiClient
      ##
      # Initialize ApiClient attributes: +name+, +rnm_dir+, +template_inputs+, and +use_localhost+
      ##
      # [parameters:]
      # * +name+ - _String_ - Human readable scenario name.
      # * +rnm_dir+ - _String_ - Full path to the rnm_directory of inputs/results for the scenario
      # * +template_inputs+ - _String_ - Location of template inputs for the RNM-US simulation (unused)
      # * +use_localhost+ - _Bool_ - Flag to use localhost API vs production API
  	  def initialize(name, rnm_dir, use_localhost=false, reopt=false)
  	  	# todo: add NREL developer api key support
  	  	@use_localhost = use_localhost
  	  	if @use_localhost
  	  		@base_api = "http://0.0.0.0:8080/api/v1/"
  	  	else
  	  		@base_api = "http://0.0.0.0:8080/api/v1/"
        end

        # params
        @name = name
        @rnm_dir = rnm_dir
        @reopt = reopt

        # double check files exist
  	  		
        # initialize @@logger
        @@logger ||= URBANopt::RNM.logger

        # simulation data
        @sim_id = ''
        # results are not really used in memory.  results.json is saved to rnm_dir when results are downloaded
        @results = {}

  	  end

      ## 
      # Check and Zip files
      ##
      def zip_input_files()

        input_files = ['cust_profile_p.txt', 'cust_profile_p_extendido.txt', 'cust_profile_q.txt', 'cust_profile_q_extendido.txt',
                      'customers.txt', 'customers_ext.txt', 'ficheros_entrada.txt', 'ficheros_entrada_inc.txt',
                      'primary_substations.txt', 'streetmapAS.txt', 'udcons.csv']
        reopt_files = ['gen_profile_p.txt', 'gen_profile_p_extendido.txt', 'gen_profile_q.txt', 
                       'gen_profile_q_extendido.txt', 'generators.txt']
    
        if @reopt
          input_files += reopt_files
        end

        puts "INPUT FILES: #{input_files}"

        # check that all files exist in folder
        missing_files = []
        input_files.each do |f|
          if !File.exists?(File.join(@rnm_dir, f))
            missing_files << f
          end
        end 

        if missing_files.size > 0
          raise "Input Files missing in directory: #{missing_files.join(',')}"
        end           

        # zip up
        Zip::File.open(File.join(@rnm_dir, 'inputs.zip'), Zip::File::CREATE) do |zipfile|
          input_files.each do |filename|
            # Two arguments:
            # - The name of the file as it will appear in the archive
            # - The original file, including the path to find it
            zipfile.add(filename, File.join(@rnm_dir, filename))
          end
        end

      end

      ##
      # Submit simulation to RNM-US API
      # Stores sim_id in the class instance 
      ##
  	  def submit_simulation()
  	  	conn = Faraday.new(url: @base_api) do |f|
  	  		f.request :multipart
  	  	end

  	  	# add post data
  	  	payload = {name: @name}
  	  	files = {'inputs': 'inputs.zip'}
  	  	files.each do |key, the_file|
  	  		payload[key] = Faraday::FilePart.new(File.join(@rnm_dir, the_file), the_file)
  	  	end

  			resp = conn.post('simulations', payload)
        
        if resp.status != 200
          msg = "Error submitting simulation to RNM-US API: status code #{resp.status} #{data['status']} - #{data['message']}"
          @@logger.error(msg)
          raise msg
        end

        data = JSON.parse(resp.body)
        @sim_id = data['simulation_id']
  	  end

      ##
      # Poll for results of RNM-US simulation and download
      # when simulation is completed, results.zip file is downloaded to rnm_dir directory
      ##
  	  def get_results()
  	  	# poll until results are returned
        done = false
        conn = Faraday.new(url: @base_api)

        max_tries = 10
        tries = 0
        puts "attempting to retrieve results for simulation #{@sim_id}"
        while !done and max_tries != tries
          resp = conn.get("simulations/#{@sim_id}")
          if resp.status == 200
            data = JSON.parse(resp.body)
            if data['status'] && ['failed', 'completed'].include?(data['status'])
              # done
              done = true
              if data['status'] == 'failed'
                if data['results'] && data['results']['message']
                  puts "Simulation Error: #{data['results']['message']}"
                else
                  puts "Simulation Error!"
                end
              else
                # get results
                @results = data['results']
                # download results
                download_results
                return
              end
            else
              tries += 1
              sleep(1)
            end

          else
            puts ("ERROR retrieving: #{resp.body}")
            tries += 1

            if tries == max_tries
              # now raise the error
              msg = "Error retrieving simulation #{@sim_id}. error code: #{resp.status}"
              @@logger.error(msg)
              raise msg
            else
              # try again
              puts ("TRYING AGAIN...#{tries}")
              sleep(3)
            end
          end 
        end

  	  end

      ##
      # Download results of a specific simulation from RNM-US API. attributes: +sim_id+
      # Results.zip file is downloaded to the rnm_dir directory
      ##
      # [parameters:]
      # * +sim_id+ - _String_ - Simulation ID to retrieve. If not nil, will override id stored in class instance
  	  def download_results(sim_id=nil)
  	  	conn = Faraday.new(url: @base_api)
        streamed = []

        the_sim_id = sim_id.nil? ? @sim_id : sim_id

        resp = conn.get("download/#{the_sim_id}") do |req|  
          req.options.on_data = Proc.new do |chunk, overall_received_bytes|
            puts "Received #{overall_received_bytes} characters"
            streamed << chunk
          end
        end
        puts("STATUS: #{resp.status}, #{resp.body}")

        if resp.status == 200
          if !Dir.exist?(File.join(@rnm_dir, 'results'))
            Dir.mkdir(File.join(@rnm_dir, 'results'))
          end

          file_path = File.join(@rnm_dir, 'results', 'results.zip')

          File.open(file_path, "wb") { |f| f.write streamed.join }
          puts "RNM-US results.zip downloaded to #{@rnm_dir}"
          # unzip
          Zip::File.open(file_path) do |zip_file|
            zip_file.each do |f|
              f_path = File.join(@rnm_dir, 'results', f.name)
              FileUtils.mkdir_p(File.dirname(f_path))
              zip_file.extract(f, f_path) unless File.exist?(f_path)
            end
          end

          # delete zip
          File.delete(file_path)
          
        else
          msg = "Error retrieving results for #{the_sim_id}. error code: #{resp.status}.  #{resp.body}"
          @@logger.error(msg)
          raise msg
        end
  	  end

  	end
  end
end

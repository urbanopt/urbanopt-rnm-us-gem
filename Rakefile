# *********************************************************************************
# URBANopt (tm), Copyright (c) 2019-2022, Alliance for Sustainable Energy, LLC, and other
# contributors. All rights reserved.

# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:

# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.

# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.

# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.

# Redistribution of this software, without modification, must refer to the software
# by the same designation. Redistribution of a modified version of this software
# (i) may not refer to the modified version by the same designation, or by any
# confusingly similar designation, and (ii) must refer to the underlying software
# originally provided by Alliance as "URBANopt". Except to comply with the foregoing,
# the term "URBANopt", or any confusingly similar designation may not be used to
# refer to any modified version of this software or any modified version of the
# underlying software originally provided by Alliance without the prior written
# consent of Alliance.

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

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

# Load in the rake tasks from the base extension gem
require 'urbanopt/rnm'

require 'rubocop/rake_task'
RuboCop::RakeTask.new

task default: :spec

# example rake task
desc 'Return gem version number'
task :version_number do
  puts "Version is: #{URBANopt::RNM::VERSION}"
end

# create input files for a project
# pass in the path to the scenario csv, the path to the json feature file, and whether this a reopt analysis (true/false)
desc 'Create input files'
task :create_inputs, [:scenario_csv_path, :feature_file_path, :reopt, :opendss_catalog] do |t, args|
  puts 'Creating input files'
  # if no path passed in, use default:
  scenario_csv_path = args[:scenario_csv_path] || 'spec/test/example_project/baseline_scenario.csv'
  root_dir, scenario_file_name = File.split(File.expand_path(scenario_csv_path))
  scenario_name = File.basename(scenario_file_name, File.extname(scenario_file_name))
  run_dir = File.join(root_dir, 'run', scenario_name.downcase)
  puts "SCENARIO NAME: #{scenario_name}"

  # set up variables
  feature_file_path = args[:feature_file_path] || File.join(root_dir, 'example_project_with_network_and_streets.json')
  reopt = args[:reopt] || false
  reopt = reopt == 'true'
  opendss_catalog = args[:opendss_catalog] || false
  opendss_catalog = opendss_catalog == 'true'

  extended_catalog_path = File.join(File.dirname(__FILE__), 'catalogs',  'extended_catalog.json')
  average_peak_catalog_path = File.join(File.dirname(__FILE__), 'catalogs', 'average_peak_per_building_type.json')

  if !File.exist?(File.join(File.dirname(__FILE__), '..', 'test'))
    FileUtils.mkdir_p(File.join(File.dirname(__FILE__), '..', 'test'))
  end

  # generate inputs
  runner = URBANopt::RNM::Runner.new(scenario_name, run_dir, scenario_csv_path, feature_file_path, extended_catalog_path: extended_catalog_path, average_peak_catalog_path: average_peak_catalog_path, reopt: reopt, opendss_catalog: opendss_catalog)
  runner.create_simulation_files
  puts '....done!'
end

# create input files for a project using defaults
# pass in the path to the scenario csv, the path to the json feature file, and whether this a reopt analysis (true/false)
desc 'Create input files with defaults'
task :create_inputs_default, [:scenario_csv_path, :feature_file_path] do |t, args|
  puts 'Creating input files with defaulted settings'
 # if no path passed in, use default:
  scenario_csv_path = args[:scenario_csv_path] || 'spec/test/example_project/baseline_scenario.csv'
  root_dir, scenario_file_name = File.split(File.expand_path(scenario_csv_path))
  scenario_name = File.basename(scenario_file_name, File.extname(scenario_file_name))
  run_dir = File.join(root_dir, 'run', scenario_name.downcase)
  puts "SCENARIO NAME: #{scenario_name}"

  # set up variables
  feature_file_path = args[:feature_file_path] || File.join(root_dir, 'example_project_with_network_and_streets.json')

  if !File.exist?(File.join(File.dirname(__FILE__), '..', 'test'))
    FileUtils.mkdir_p(File.join(File.dirname(__FILE__), '..', 'test'))
  end

  # generate inputs
  runner = URBANopt::RNM::Runner.new(scenario_name, run_dir, scenario_csv_path, feature_file_path)
  runner.create_simulation_files
  puts '....done!'
end

# run simulation and retrieve results
# pass in the path to the scenario csv, whether this is a reopt analysis (true/false), and whether to use localhost RNM API (true/false)
desc 'Run Simulation'
task :run_simulation, [:scenario_csv_path, :reopt, :use_localhost] do |t, args|
  puts 'Running simulation'
  # if no path passed in, use default:
  scenario_csv = args[:scenario_csv_path] || 'spec/test/example_project/run/baseline_scenario'
  root_dir, scenario_file_name = File.split(File.expand_path(scenario_csv))
  scenario_name = File.basename(scenario_file_name, File.extname(scenario_file_name))
  run_dir = File.join(root_dir, 'run', scenario_name.downcase)

  rnm_dir = File.join(run_dir, 'rnm-us')
  reopt = args[:reopt] || false
  reopt = reopt == 'true'

  use_localhost = args[:use_localhost] || false
  use_localhost = use_localhost == 'true'

  if !File.exist?(rnm_dir)
    raise 'No rnm-us directory found for this scenario...run the create_inputs rake task first.'
  end

  puts "scenario dir path: #{run_dir}"
  puts "reopt: #{reopt}"
  puts "use_localhost: #{use_localhost}"
  api_client = URBANopt::RNM::ApiClient.new(scenario_name, rnm_dir, use_localhost = use_localhost, reopt = reopt)
  # zip inputs
  api_client.zip_input_files
  api_client.submit_simulation
  api_client.get_results

  puts '...done!'
end

# Create opendss catalog from extended catalog
# pass in the path and filename where the OpenDSS catalog should be saved
desc 'Create OpenDSS catalog'
task :create_opendss_catalog, [:save_path] do |t, args|
  puts 'Creating OpenDSS catalog'
  # if no path passed in, use default (current dir):
  save_path = args[:save_path] || './opendss_catalog.json'

  extended_catalog_path = File.join(File.dirname(__FILE__), 'catalogs', 'extended_catalog.json')
  opendss_catalog = URBANopt::RNM::ConversionToOpendssCatalog.new(extended_catalog_path)
  # create catalog and save to specified path
  opendss_catalog.create_catalog(save_path)

  puts "Catalog saved to #{save_path}"
  puts '....done!'
end

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
# pass in the path to the scenario directory and the path to the json feature file
desc 'Create input files'
task :create_inputs, [:scenario_dir_path, :feature_file_path] do |t, args|
	puts "Creating input files"
	# if no path passed in, use default:
	scenario_dir = args[:scenario_dir_path] ? args[:scenario_dir_path] : "../uo_example_project/run/baseline_scenario"

	run_dir = scenario_dir
	root_dir = File.join(run_dir, '..', '..') # 2 levels up
	
	feature_file_path = args[:feature_file_path] ? args[:feature_file_path]: File.join(root_dir,  'example_project_streets_old.json')

	# set up some variables 
  reopt = false
  extended_catalog_path = File.join(File.dirname(__FILE__), 'catalogs',  'extended_catalog.json')
  average_peak_catalog_path = File.join(File.dirname(__FILE__), 'catalogs',  'average_peak_per_building_type.json')
  scenario_name = Pathname.new(scenario_dir).basename 
      
  if !File.exists?(File.join(File.dirname(__FILE__), '..', 'test'))
    FileUtils.mkdir_p(File.join(File.dirname(__FILE__), '..', 'test'))
  end
	
	# generate inputs     
  runner = URBANopt::RNM::Runner.new(scenario_name, root_dir, run_dir, feature_file_path, reopt, extended_catalog_path, average_peak_catalog_path)
  runner.create_simulation_files
  puts "....done!"
end

# Create opendss catalog from extended catalog
# pass in the path and filename where the OpenDSS catalog should be saved
desc 'Create OpenDSS catalog'
task :create_opendss_catalog, [:save_path] do |t, args|

	puts "Creating OpenDSS catalog"
	# if no path passed in, use default (current dir):
	save_path = args[:save_path] ? args[:save_path] : "./opendss_catalog.json"

	extended_catalog_path = File.join(File.dirname(__FILE__), 'catalogs',  'extended_catalog.json')
	opendss_catalog = URBANopt::RNM::Conversion_to_opendss_catalog.new(extended_catalog_path)
  # create catalog and save to specified path
  opendss_catalog.create_catalog(save_path)

  puts "Catalog saved to #{save_path}"
  puts "....done!"

end
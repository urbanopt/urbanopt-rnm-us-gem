# *********************************************************************************
# URBANopt™, Copyright © Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-rnm-us-gem/blob/develop/LICENSE.md
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

# Full Runner workflow (mimics UO CLI functionality)
# pass in the path to the scenario csv, geojson path, whether this is a reopt analysis (true/false), and whether to use localhost RNM API (true/false)
desc 'Full Runner workflow'
task :full_runner_workflow, [:scenario_csv_path, :geojson_path, :reopt, :use_localhost] do |t, args|
  # todo: could allow passing in extended catalog, average peak catalog, and opendss_catalog flags too
  # if no path passed in, use default:
  scenario_csv = args[:scenario_csv_path] || 'spec/test/example_project/run/baseline_scenario'
  geojson_path = args[:geojson_path] || 'spec/test/example_project/example_project_with_network_and_streets'
  root_dir, scenario_file_name = File.split(File.expand_path(scenario_csv))
  scenario_name = File.basename(scenario_file_name, File.extname(scenario_file_name))
  run_dir = File.join(root_dir, 'run', scenario_name.downcase)
  reopt = args[:reopt] || false
  reopt = reopt == 'true'
  use_local =  args[:use_localhost] || false

  runner = URBANopt::RNM::Runner.new(scenario_name, run_dir, scenario_csv, geojson_path, reopt: reopt)
  runner.create_simulation_files
  runner.run(use_local)
  runner.post_process

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


# run validation
# pass in the path to the scenario csv
desc 'Run Validation'
task :run_validation, [:scenario_csv_path, :use_numeric_ids] do |t, args|
  #Exammple to run validation
  #bundle exec rake run_validation[D:/.../urbanopt-rnm-us-gem/spec/files/example_project/baseline_scenario.csv,true]

  puts 'Running OpenDSS validation'

  # if no path passed in, use default:
  scenario_csv = args[:scenario_csv_path] || 'spec/test/example_project/run/baseline_scenario'
  root_dir, scenario_file_name = File.split(File.expand_path(scenario_csv))
  scenario_name = File.basename(scenario_file_name, File.extname(scenario_file_name))
  run_dir = File.join(root_dir, 'run', scenario_name.downcase)
  rnm_dir = File.join(run_dir, 'rnm-us')

  #Use numeric ids (for the hierarchical plot of the network)
  use_numeric_ids = args[:use_numeric_ids] || false
  use_numeric_ids = use_numeric_ids == 'true'

  if !File.exist?(rnm_dir)
    puts rnm_dir
    raise 'No rnm-us directory found for this scenario...run the create_inputs rake task first.'
  end

  puts "run dir path: #{run_dir}"
  validation = URBANopt::RNM::Validation.new(rnm_dir,use_numeric_ids)
  validation.run_validation()

  puts '...done!'
end

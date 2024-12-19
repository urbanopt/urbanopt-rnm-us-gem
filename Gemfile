source 'http://rubygems.org'

# Specify your gem's dependencies in urbanopt-scenario-gem.gemspec
gemspec

# if you want to use local gems during development, use this environment variable to enable them
allow_local = ENV['FAVOR_LOCAL_GEMS']

gem 'openstudio-extension', github: 'NREL/openstudio-extension-gem', branch: 'bundler-hack'

# if allow_local && File.exists?('../urbanopt-geojson-gem')
# gem 'urbanopt-geojson', path: '../urbanopt-geojson-gem'
# elsif allow_local
gem 'urbanopt-geojson', github: 'URBANopt/urbanopt-geojson-gem', branch: 'os39'
# end

# Temporary! Remove this once core-gem is merged/released
gem 'urbanopt-core', github: 'URBANopt/urbanopt-core-gem', branch: 'os39'

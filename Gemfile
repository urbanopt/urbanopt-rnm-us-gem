source 'http://rubygems.org'

# Specify your gem's dependencies in urbanopt-scenario-gem.gemspec
gemspec

# if you want to use local gems during development, use this environment variable to enable them
allow_local = ENV['FAVOR_LOCAL_GEMS']

# Below is an example of how to configure the gemfile for developing with local gems
# modify as appropriate

# if allow_local && File.exists?('../urbanopt-geojson-gem')
#   gem 'urbanopt-geojson', path: '../urbanopt-geojson-gem'
# elsif allow_local
  gem 'urbanopt-geojson', github: 'URBANopt/urbanopt-geojson-gem', branch: 'os361'
# end

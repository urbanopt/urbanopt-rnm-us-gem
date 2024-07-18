source 'http://rubygems.org'

# Specify your gem's dependencies in urbanopt-scenario-gem.gemspec
gemspec

# if you want to use local gems during development, use this environment variable to enable them
allow_local = ENV['FAVOR_LOCAL_GEMS']

# pin this dependency to avoid unicode_normalize error
# gem 'addressable', '2.8.1'
# pin this dependency to avoid using racc dependency (which has native extensions)
# gem 'parser', '3.2.2.2'

# Below is an example of how to configure the gemfile for developing with local gems
# modify as appropriate

# if allow_local && File.exists?('../urbanopt-geojson-gem')
  # gem 'urbanopt-geojson', path: '../urbanopt-geojson-gem'
# elsif allow_local
 gem 'urbanopt-geojson', github: 'URBANopt/urbanopt-geojson-gem', branch: 'os38'
# end

# Temporary! Remove this once core-gem is merged/released
gem 'urbanopt-core', github: 'URBANopt/urbanopt-core-gem', branch: 'os38'

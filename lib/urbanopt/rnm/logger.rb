# *********************************************************************************
# URBANopt™, Copyright © Alliance for Sustainable Energy, LLC.
# See also https://github.com/urbanopt/urbanopt-rnm-us-gem/blob/develop/LICENSE.md
# *********************************************************************************

require 'logger'

module URBANopt
  module RNM
    @@logger = Logger.new($stdout)

    # Definining class variable "@@logger" to log errors, info and warning messages.
    def self.logger
      @@logger
    end
  end
end

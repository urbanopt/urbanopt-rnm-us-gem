# Changelog

## Version 0.7.0
Date Range 06/30/23 - 01/09/24

* remove Jenkinsfile by @vtnate in https://github.com/urbanopt/urbanopt-rnm-us-gem/pull/34
* also run CI when a PR gets a review request by @vtnate in https://github.com/urbanopt/urbanopt-rnm-us-gem/pull/35
* Support OpenStudio 3.7 by @vtnate in https://github.com/urbanopt/urbanopt-rnm-us-gem/pull/36

**Full Changelog**: https://github.com/urbanopt/urbanopt-rnm-us-gem/compare/v0.6.0...v0.7.0

## Version 0.6.0
Date Range: 6/7/23 - 6/30/23

- Update dependencies & CI for OpenStudio 3.6.1
- Update license and references to the license file
- Remove unnecessary dev dependency on rubocop as rubocop comes in from other dependencies
- Reactivate GitHub Actions for CI

## Version 0.5.1
Date Range 12/9/22 - 6/7/23

- Fix to handle buildings with courtyard without creating additional erroneous buildings

## Version 0.5.0
Date Range 9/30/22 - 12/8/22

- Update dependencies for Extension Gem 0.6.0 and OpenStudio 3.5.0

## Version 0.4.0
Date Range 05/10/22 - 9/30/22

- Breaking changes to electrical catalog used and compatible RNM-US executable.
- Update API to version 2. API v1 still working for older URBANopt SDK releases but no longer working for future versions.

## Version 0.3.0
Date Range 11/23/21 - 05/10/22

- Update copyrights

## Version 0.2.0

Date Range 11/09/21 - 11/22/21

- Updated dependencies for OpenStudio 3.3

## Version 0.1.3

Date Range 11/02/21 - 11/08/21

- Fix [#11](https://github.com/urbanopt/urbanopt-rnm-us-gem/issues/11), results files are not downloading in project directory for large projects

- Fix [#16](https://github.com/urbanopt/urbanopt-rnm-us-gem/issues/16), fix residential enums to be consistent across files and fix typo in multifamily

## Version 0.1.2

Date Range 10/29/21 - 11/01/21

- Fix [#13](https://github.com/urbanopt/urbanopt-rnm-us-gem/issues/13), update rubyzip dependency to fix conflict

## Version 0.1.1

Date Range 07/22/21 - 10/28/21

- Fixed [#10]( https://github.com/urbanopt/urbanopt-rnm-us-gem/issues/7 ), Fix peak profile generation for prosumer profiles
- Fixed [#8]( https://github.com/urbanopt/urbanopt-rnm-us-gem/issues/8 ), Use timestep_per_hour defined in UO feature report for the interval reporting
- Fixed [#10]( https://github.com/urbanopt/urbanopt-rnm-us-gem/issues/10 ), Add other residential types to prosumer/consumer calculations

## Version 0.1.0

Initial version of the RNM-US gem.

[![Coverage Status](https://coveralls.io/repos/github/urbanopt/urbanopt-rnm-us-gem/badge.svg?branch=develop)](https://coveralls.io/github/urbanopt/urbanopt-rnm-us-gem?branch=develop)
[![RNM-gem CI](https://github.com/urbanopt/urbanopt-rnm-us-gem/actions/workflows/nightly_ci_build.yml/badge.svg)](https://github.com/urbanopt/urbanopt-rnm-us-gem/actions/workflows/nightly_ci_build.yml)

# URBANopt RNM-US Gem

The URBANopt<sup>&trade;</sup> RNM-US Gem includes functionalities to interface the URBANopt SDK to the RNM-US Gem for the development of a synthetic optimum distribution network in the considered district, given data related to the buildings energy consumption/DER energy generation and location, modeled by the other URBANopt modules.
The RNM-US Gem is used to collect required data for the execution of RNM-US, which has been modeled in the other URBANopt modules, translating information provided
in .json and .csv format into .txt files

## Usage

The URBANopt RNM-US Gem extracts output values from the other URBANopt Gems, to create required input files for the execution of the RNM-US software for the development of a synthetic distribution grid.

RNM-US provides output results in GIS, JSON and OpenDSS format. The results in GIS format outline the graphical representation of the synthetic distribution network modeled, including a visual outline of the street map of the considered district, the location of the consumers, transformers and substations, including the power lines layout.
The JSON format output provides a set of results regarding size, costs and measures of the synthetic network modelled.
The OpenDSS format presents results for power system analysis and simulations.

The current functionalities of the RNM-US Gem include the creation of a streetmap text file, the substation txt file and multiple txt files related to the consumers peak loads and profiles and DERs peak generation and profiles.
The streetmap text file is developed from coordinates information provided by geoJSON feature file input. The customers and generators text files, which define all the network consumers and DG included in the project, are created from their peak electricity demand/generation, and building location, provided by csv and json feature_report files modeled by the URBANopt Scenario Gem.
The profiles txt files are divided among the consumers hourly profiles of active and reactive power and the DG hourly profiles of active and reactive power for the 2 most "extreme" days of maximum net demand and maximum net generation for the district .
Finally, the extended profiles txt files provide the active and reactive profiles for each consumer/DG for the whole year.


## Generate input files

The `create_inputs` rake command can be used to generate the RNM-US inputs for an arbitrary command.  You will need to specify the path to the scenario results directory and the path to the GeoJSON feature file:

```bash
  bundle exec rake create_inputs[/path/to/example_project/run/scenario_name,/path/to/feature_file.json]
```

### Options

Several options can be set when creating the input files and running the RNM-US process.

1. REopt: Set the `reopt` argument to `true` when initializing the runner to use REopt results in the RNM-US inputs.
1. Underground cables ratio:  Set the `underground_cables_ratio` field at the project level in the JSON Feature File to specify the ratio of underground cables to overhead cables.  If this field is not set, the default value of 0.9 will be used.
1. Low-Voltage Only: Set the boolean `only_lv_consumers` field at the project level in the JSON Feature File.  If set to `true`, only low voltage consumers will be considered in the RNM analysis. If this field is not set, the default value of `true` will be used.

## Generating OpenDSS catalog

An OpenDSS-formatted catalog can be generated from the extended catalog with the following command:

```bash
bundle exec rake create_opendss_catalog[/desired/path/to/opendss_catalog.json]
```

## RNM-US API compatibility

| API Version | RNM-US Gem Version | RNM-US exe Version |
| ----------- | ------------------ | ------------------ |
| v1          | 0.3.0 and earlier  | RNM-US_20220819    |
| v2          | 0.4.0              | RNM-US_20221018    |


## Validation Functionality

The validation and results visualization functionality is written in python. Follow these steps if you would like to use it.

1. Install python (>=3.10) if you do not already have it installed
1. Clone the repo to your computer
1. cd into the repo directory
1. run `bundle install` to install the required ruby dependencies
1. run `pip install -r requirements.txt` to install the required python dependencies for the validation module
1. create input files and run the simulation as usual
1. run `bundle exec rake run_validation[/path/to/scenario/csv]` to run the validation


## Testing

```bash
bundle exec rspec
```

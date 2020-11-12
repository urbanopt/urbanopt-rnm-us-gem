# URBANopt RNM-US Gem

The URBANopt RNM-US Gem includes functionalities to interface the URBANopt SDK to RNM-US Gem for the development of a synthetic optimum distribution network in the considered district, given data related to the buildings energy consumption/DER energy generation and location, modeled by the other URBANopt modules. 
The rnm module is used to collect required data for the execution of the RNM-US, which has been modeled in the other URBANopt modules, translating information provided
in .json and .csv format into .txt files

## Usage

The URBANopt RNM-US gem is an interface with the purpose of extracting output values from the other URBANopt Gems, to create required input files for the execution of the RNM-US software for the development of a synthetic distribution grid.

RNM-US provides output results in GIS, JSON and OpenDSS format. The results in GIS format  outline the graphical representation of the synthetic distribution network modeled, including a visual outline of the street map of the considered district, the location of the consumers, transformers and substations, including the power lines layout.
The JSON format output provides a set of results regarding size, costs and measures of the synthetic network modelled.
The OpenDSS format presents results for power system analysis and simulations.

The current functionalities of the RNM-US Gem include the creation of a streetmap text file and customers text files.
The streetmap text file is developed from coordinates information provided by geoJSON feature file input. The customers text files, which define all the network consumers included in the project, are created from their peak electricity demand, and building location, provided by csv and json feature_report files modeled by the URBANopt Scenario module.
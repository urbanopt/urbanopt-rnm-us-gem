import opendssdirect as dss       
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import sys as sys
import math
import networkx as nx
import opendss_interface
import plot_lib

class Validation:
    def __init__(self, folder):
        self.folder = folder
        
    def main_validation(self):
        master_file_full_path = folder + '/dss_files/' + 'Master.dss'
        start_index = 0
        num_periods=12
        end_index = 8760
        v_range_voltage=(0.9, 1.1)
        v_limits_voltage=[0.95,1.05]
        v_range_loading=(0,1.3)
        v_limits_loading=[1]
        v_range_show_all=(0,0)

        #For tests
        #end_index = 24
        #v_range_voltage=(0.975, 1.025)

        myopendss_io=opendss_interface.OpenDSS_Interface(folder)
        v_dict_voltage,v_voltage_yearly,v_voltage_period,v_power_yearly,v_power_period,v_dict_loading,v_loading_yearly,v_loading_period,v_dict_losses,v_subs_losses_yearly,v_line_losses_yearly,dict_buses_element=myopendss_io.solve_powerflow_iteratively(num_periods,start_index,end_index,master_file_full_path,v_range_voltage,v_range_loading)
        myopendss_io.write_dict(v_dict_voltage,v_range_show_all,'Voltages (p.u.)','Buses')
        myopendss_io.write_dict(v_dict_voltage,v_range_voltage,'Voltage Violations (p.u.)','Buses')
        myopendss_io.write_dict(v_dict_loading,v_range_show_all,'Loading (p.u.)','Branches')
        myopendss_io.write_dict(v_dict_loading,v_range_loading,'Loading Violations (p.u.)','Branches')
        myopendss_io.write_dict(v_dict_losses,v_range_show_all,'Losses','Branches')        
        edges=myopendss_io.get_edges()
        myplot_lib=plot_lib.Plot_Lib(folder)
        myplot_lib.plot_hist('Voltage',v_voltage_yearly,v_voltage_period,v_range_voltage,40,num_periods,v_limits_voltage)
        myplot_lib.plot_hist('Loading',v_loading_yearly,v_loading_period,v_range_loading,80,num_periods,v_limits_loading)
        myplot_lib.plot_losses(v_subs_losses_yearly,v_line_losses_yearly)    
        myplot_lib.plot_graph(edges,v_dict_voltage,v_range_voltage,v_dict_loading,v_range_loading,dict_buses_element)



if __name__ == "__main__":
    #Example to run it in command window
    #python main_validation.py files
    folder = sys.argv[1]
    valid=Validation(folder)
    valid.main_validation()

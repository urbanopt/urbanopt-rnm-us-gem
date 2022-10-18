import opendssdirect as dss       
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import sys as sys
import math
import networkx as nx
import opendss_interface
import plot_lib
import report
import os

class Validation:
    def __init__(self, folder,b_numeric_ids):
        """Initialices the folder variables"""
        self.main_folder = folder        #Main uppper level folder (needed to search for OpenDSS files)     
        self.folder=folder+'/Validation' #Folder where the Validation results are saved
        self.b_numeric_ids=b_numeric_ids
        self.mkdir(self.folder)          #It creates the validation folder if it does not exist

    def mkdir(self,directory):
        """Checkes whether the folder exists, if not it creates it"""
        if (not os.path.exists(directory)):
            os.mkdir(directory)

    def make_dirs(self):
        """Creates all the subfolder, it they don't exist"""
        path=self.folder+'/'        
        self.mkdir(path+'Voltage')
        self.mkdir(path+'Voltage/CSV')
        self.mkdir(path+'Voltage/Figures')
        self.mkdir(path+'Unbalance')
        self.mkdir(path+'Unbalance/CSV')
        self.mkdir(path+'Unbalance/Figures')
        self.mkdir(path+'Loading')
        self.mkdir(path+'Loading/CSV')
        self.mkdir(path+'Loading/Figures')
        self.mkdir(path+'Losses')
        self.mkdir(path+'Losses/CSV')
        self.mkdir(path+'Losses/Figures')
        self.mkdir(path+'Loads')
        self.mkdir(path+'Loads/Figures')
        self.mkdir(path+'Equipment')
        self.mkdir(path+'Equipment/Figures')
        self.mkdir(path+'Network')
        self.mkdir(path+'Network/Figures')
        self.mkdir(path+'Summary')
    
    def define_ranges(self):
        """Defines the allowed ranges (to determine violations), the limits (to plot the lines in the plots), and the display ranges (for the axis in the figures)"""
        #Voltages
        v_range_voltage={}
        v_range_voltage['allowed_range']=(0.95, 1.05)
        v_range_voltage['limits']=[0.95, 1.05]
        v_range_voltage['display_range']=(0.85, 1.15)
        #Lodaing
        v_range_loading={}
        v_range_loading['allowed_range']=(0, 1)
        v_range_loading['limits']=[1]
        v_range_loading['display_range']=(0, 1.3)
        #Unbalance
        v_range_unbalance={}
        v_range_unbalance['allowed_range']=(0,0.02)
        v_range_unbalance['limits']=[0.02]
        v_range_unbalance['display_range']=(0,0.021)
        #Show all variables option
        v_range_show_all={}
        v_range_show_all['allowed_range']=()
        v_range_show_all['limits']=[]
        v_range_show_all['display_range']=()        

        return v_range_voltage,v_range_loading,v_range_unbalance,v_range_show_all


    def main_validation(self):
        """Carries out the whole validation of the distribution system"""
        #Path and file name
        master_file_full_path = self.main_folder + '/dss_files/' + 'Master.dss' #Path for the Master file        
        start_index = 0  #Default initial index (needed to run OpenDSS)
        num_periods=12   #Number of periods (12 month)
        end_index = 8760 #Default final index, 1 year, 8760h (needed to run OpenDSS)

        #Create sub-folders
        self.make_dirs()
        #Define the ranges of voltage, loading, unbalance and a default range to show all the values
        v_range_voltage,v_range_loading,v_range_unbalance,v_range_show_all=self.define_ranges()

        #For tests
        #end_index = 24  #Simulate few hours (still broken down in 12 periods)
        #v_range_voltage['allowed_range']=(0.975, 1.025)    #More stringent limmits than the standard ones to show violations
        #v_range_loading['allowed_range']=(0,0.3)
        #v_range_unbalance['allowed_range']=(0, 4e-5)
        #v_range_unbalance['allowed_range']=(0, 2.1e-5)

        #Run power flow iteratively and obtain the results
        myopendss_io=opendss_interface.OpenDSS_Interface(folder,self.b_numeric_ids)
        v_dict_buses_ids,v_dict_ids_buses,v_dict_voltage,v_voltage_yearly,v_voltage_period,v_power_yearly,v_power_period,v_dict_loading,v_loading_yearly,v_loading_period,v_dict_losses,v_subs_losses_yearly,v_line_losses_yearly,dict_buses_element,v_dict_loads,v_loads_kw_yearly,v_loads_kw_period,v_loads_kvar_yearly,v_loads_kvar_period,v_total_load_kw_yearly,v_total_load_kvar_yearly, v_loads_kw, v_loads_kvar, v_dict_unbalance,v_unbalance_yearly,v_unbalance_period,dict_lines,v_lines_norm_amps,dict_transformers,v_transformers_kva=myopendss_io.solve_powerflow_iteratively(num_periods,start_index,end_index,master_file_full_path,v_range_voltage,v_range_loading,v_range_unbalance)

        #Save voltage, unbalance, loading and losses results in CSV files
        myopendss_io.write_dict('Voltage/CSV',v_dict_voltage,v_range_show_all,'Voltages (p.u.)','Buses',v_dict_buses_ids)
        myopendss_io.write_dict('Voltage/CSV',v_dict_voltage,v_range_voltage,'Voltage Violations (p.u.)','Buses',v_dict_buses_ids)
        myopendss_io.write_dict('Unbalance/CSV',v_dict_unbalance,v_range_show_all,'Unbalance (p.u.)','Buses',v_dict_buses_ids)
        myopendss_io.write_dict('Unbalance/CSV',v_dict_unbalance,v_range_unbalance,'Unbalance Violations (p.u.)','Buses',v_dict_buses_ids)
        myopendss_io.write_dict('Loading/CSV',v_dict_loading,v_range_show_all,'Loading (p.u.)','Branches',None)
        myopendss_io.write_dict('Loading/CSV',v_dict_loading,v_range_loading,'Loading Violations (p.u.)','Branches',None)
        myopendss_io.write_dict('losses/CSV',v_dict_losses,v_range_show_all,'Losses','Branches',None)        
        if self.b_numeric_ids:
            myopendss_io.write_id_dict('Network/Figures','IDs_Buses',v_dict_buses_ids)
        #Get the edges of the network (for later making a hierarchical representation of the network)
        closed_edges,open_edges=myopendss_io.get_edges(v_dict_buses_ids)
        #Plot all the figures
        myplot_lib=plot_lib.Plot_Lib(folder,self.b_numeric_ids)
        #Voltage
        myplot_lib.plot_hist('Voltage','Voltage (p.u.)',v_voltage_yearly,v_voltage_period,v_range_voltage,num_periods,40)
        myplot_lib.plot_violin_monthly('Voltage/Figures','Voltage (p.u.)',v_voltage_yearly,v_voltage_period,v_range_voltage,num_periods)
        #Unbalance
        myplot_lib.plot_hist('Unbalance','Unbalance (p.u.)',v_unbalance_yearly,v_unbalance_period,v_range_unbalance,num_periods,40)
        myplot_lib.plot_violin_monthly('Unbalance/Figures','Unbalance (p.u.)',v_unbalance_yearly,v_unbalance_period,v_range_unbalance,num_periods)
        #Loading
        myplot_lib.plot_hist('Loading','Loading (p.u.)',v_loading_yearly,v_loading_period,v_range_loading,num_periods,80)
        myplot_lib.plot_violin_monthly('Loading/Figures','Loading (p.u.)',v_loading_yearly,v_loading_period,v_range_loading,num_periods)
        #Loads and load shpaes
        myplot_lib.plot_duration_curve('Loads/Figures',v_total_load_kw_yearly,v_total_load_kvar_yearly,False)    
        myplot_lib.plot_violin_monthly_two_vars('Loads/Figures','Loads',v_loads_kw_yearly,v_loads_kw_period,v_loads_kvar_yearly,v_loads_kvar_period,v_range_show_all,num_periods)
        myplot_lib.plot_violin('Loads/Figures','Loads Peak (kW)',v_loads_kw,v_range_show_all)
        #Losses
        myplot_lib.plot_duration_curve('Losses/Figures',v_subs_losses_yearly,v_line_losses_yearly,True)    
        #Equipment parameters
        myplot_lib.plot_violin('Equipment/Figures','Power Line - Normal Amps (A)',v_lines_norm_amps,v_range_show_all)
        myplot_lib.plot_violin('Equipment/Figures','Transformer (kVA)',v_transformers_kva,v_range_show_all)
        #Hierarchical representation of the network
        myplot_lib.plot_graph('Network/Figures',closed_edges,open_edges,v_dict_voltage,v_range_voltage,v_dict_loading,v_range_loading,dict_buses_element,v_dict_buses_ids,v_dict_ids_buses)
        #Summary operational report
        myreport=report.Report(folder,self.b_numeric_ids)
        myreport.write_summary_operational_report('Summary',v_dict_voltage,v_range_voltage,v_dict_unbalance,v_range_unbalance,v_dict_loading,v_range_loading,v_dict_loads)
        

#def main_validation(folder): #Example: uncomment to make the script run from a function
    #folder = './files/'
if __name__ == "__main__":
    """Runs direclty as a script if called from the command window"""
    #Example of use: python main_validation.py files
    folder = sys.argv[1]        #Use the folder specified in the arguments
    b_numeric_ids=True
    valid=Validation(folder,b_numeric_ids)    
    valid.main_validation()     #Call the main validation function


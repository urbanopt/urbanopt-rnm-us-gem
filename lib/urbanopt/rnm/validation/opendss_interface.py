import opendssdirect as dss       
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import sys as sys
import math
import networkx as nx

class OpenDSS_Interface:
    def __init__(self, folder):
        self.folder = folder

    def remove_terminal(self,bus):
        if isinstance(bus,str):
            return bus.split('.')[0]
        else:
            return bus


    def extract_period(self,v_value_i,v_value_period,i,end_index,num_periods):
        for j in range(num_periods):
            if (i<=end_index*j/num_periods):
                v_value_period[j].extend(v_value_i)
                break
        return v_value_period

    def add_to_dictionary(self,v_dict_voltage,dict_voltage_i):
        for idx,name in enumerate(dict_voltage_i):
            if name in v_dict_voltage: #if not empty
                v_dict_voltage[name].append(dict_voltage_i[name])
            else:
                v_dict_voltage[name]=[dict_voltage_i[name]]

    def dss_run_command(self,command):
        output=dss.run_command(command)
        if (len(output)>0):
            print(output)


    def get_all_voltage(self):
        """Computes over and under voltages for all buses"""
        bus_names = dss.Circuit.AllBusNames()
        dict_voltage = {}
        v_voltage = [0 for _ in range(len(bus_names))]
        for idx,b in enumerate(bus_names):
            dss.Circuit.SetActiveBus(b)
            vang = dss.Bus.puVmagAngle()
            if len(vang[::2]) > 0:
                vmag = sum(vang[::2])/(len(vang)/2)
            else:
                vmag = 0
            dict_voltage[b] = vmag
            v_voltage[idx]=vmag

        return dict_voltage,v_voltage

    def get_all_power(self):
        """Computes power in all circuits"""
        circuit_names = dss.Circuit.AllElementNames()
        dict_power = {}
        v_power = [0 for _ in range(len(circuit_names))]
        for idx,b in enumerate(circuit_names):
            dss.Circuit.SetActiveElement(b)
            power = dss.CktElement.Powers()
            if len(power[::2]) > 0:
                poweravg = sum(power[::2])/(len(power)/2)
            else:
                poweravg = 0
            dict_power[b] = poweravg
            v_power[idx]=poweravg

        return dict_power,v_power


    def get_all_loading(self):
        """Computes loading in all circuits"""
        circuit_names = dss.Circuit.AllElementNames()
        dict_loading = {}
        dict_buses_element={} #Associate the element to the buses (this has the inconvenient that only associates one element to each pair of buses)
        v_loading = [0 for _ in range(len(circuit_names))]
        for idx,element in enumerate(circuit_names):
            dss.Circuit.SetActiveElement(element)
            #only if it is a branch (two buses)
            buses = dss.CktElement.BusNames()
            if (len(buses)>=2): 
                current = dss.CktElement.CurrentsMagAng()
                num_terminals=dss.CktElement.NumTerminals()
                if len(current[::2]) > 0:
                    #currentmag = sum(current[::2])/len(current[::2])
                    #Take only the average of 1 terminal (discarding phases so every 2)
                    lenc=len(current[::2])
                    stop=round(2*lenc/num_terminals)
                    #print(current[:stop:2])
                    currentmag = sum(current[:stop:2])/lenc
                else:
                    currentmag = 0
                currentmag = current[0]
                nominal_current = dss.CktElement.NormalAmps()
                #Transformers have applied a 1.1 factor in the calculation of NormalAmps
                #See library that OpenDSSdirect uses in https://github.com/dss-extensions/dss_capi/blob/master/src/PDElements/Transformer.pas
                #in particular line code AmpRatings[i] := 1.1 * kVARatings[i] / Fnphases / Vfactor;
                if (element.startswith("Transformer")):
                    nominal_current=nominal_current/1.1
                if (nominal_current>0):
                    dict_loading[element] = currentmag/nominal_current 
                    v_loading[idx]=currentmag/nominal_current                            
                    bus1to2=self.remove_terminal(buses[0])+'-->'+self.remove_terminal(buses[1])
                    dict_buses_element[bus1to2]=element

        return dict_loading,v_loading,dict_buses_element

    def get_all_losses(self):
        """Computes losses in all circuits"""
        circuit_names = dss.Circuit.AllElementNames()
        dict_losses = {}
        v_losses = [0 for _ in range(len(circuit_names))]
        total_losses=0
        for idx,element in enumerate(circuit_names):
            dss.Circuit.SetActiveElement(element)
            #only if it is a branch (two buses)
            buses = dss.CktElement.BusNames()
            if (len(buses)>=2): 
                #next if check discards vsources
                nominal_current = dss.CktElement.NormalAmps()
                if (nominal_current>0):
                    losses = dss.CktElement.Losses()
                    if len(losses) ==2:
                        lossesavg = (losses[0]) #Verify this is correct, if not abs() they range from + to -, [0] to take active losses
                    else:
                        print("error - not correctly reading losses")
                        lossesavg=0          
                    #Convert to kW. This function is the exeption that return losses in W  
                    lossesavg=lossesavg/1000 
                    dict_losses[element] = lossesavg
                    v_losses[idx]=lossesavg
        
        return dict_losses,total_losses

    def get_total_subs_losses(self):
        """Computes total substation losses"""
        return dss.Circuit.SubstationLosses()[0]  #Real part

    def get_total_line_losses(self):
        """Computes total line losses"""
        return dss.Circuit.LineLosses()[0] #Real part

    def get_edges(self):
        edges=[]
        circuit_names = dss.Circuit.AllElementNames()
        for idx,element in enumerate(circuit_names):
            dss.Circuit.SetActiveElement(element)
            buses = dss.CktElement.BusNames()
            #Only if it is a branch
            if (len(buses)>=2): #There can be 3 buses in single-phase center-tap transformer, in this case the two last ones are equals (different terminals only) and we can take just the 2 first ones
                #remove terminal from the bus name (everything to the right of point)
                edges.append([(self.remove_terminal(buses[0]),self.remove_terminal(buses[1]))])
        return edges

    def write_dict(self,v_dict,v_range,type,component):
        output_file_full_path = self.folder + '/' + type + '_' + component + '.csv'
        # Write directly as a CSV file with headers on first line
        with open(output_file_full_path, 'w') as fp:
            #Header: ID, hours (consider adding day, month in future)
            for idx,name in enumerate(v_dict):
                fp.write('Hour,'+','.join(str(idx2) for idx2,value in enumerate(v_dict[name])) + '\n')
                break
            #Write matrix
            for idx,name in enumerate(v_dict):
                #Truncate list to limits              
                truncated_values=[]
                for idx2,value in enumerate(v_dict[name]):  
                    if value<v_range[0] or value>=v_range[1]:
                        truncated_values.append(str(value))
                    else:
                        truncated_values.append("")
                fp.write(name+','+','.join(truncated_values)+'\n')
                #truncated_values=[i for i, lower, upper in zip(v_dict_voltage[name], [v_range_voltage[1]]*len(v_dict_voltage[name]), [v_range_voltage[1]]*len(v_dict_voltage[name])) if i <lower or i>upper]
                #fp.write(name+','+','.join(map(str,v_dict_voltage[name]))+'\n')


    def solve_powerflow_iteratively(self,num_periods,start_index,end_index,location,v_range_voltage,v_range_loading):
        #Por flow solving mode
        self.dss_run_command("Clear")
        self.dss_run_command('Redirect '+location)
        self.dss_run_command("solve mode = snap")
        self.dss_run_command("Set mode=yearly stepsize=1h number=1")
        #Init vectors
        v_voltage_yearly=[]
        v_voltage_period=[[] for _ in range(num_periods)]        
        v_power_yearly=[]
        v_power_period=[[] for _ in range(num_periods)]
        v_loading_yearly=[]
        v_loading_period=[[] for _ in range(num_periods)]
        v_subs_losses_yearly=[]
        v_line_losses_yearly=[]
        v_dict_voltage={}
        v_dict_loading={}
        v_dict_losses={}
        #Additional initializations
        my_range=range(start_index,end_index,1)
        old_percentage_str="" #Variable for tracking progress
        for i in my_range:
            #Solve power flow
            self.dss_run_command("Solve")
            #Get voltages
            dict_voltage_i, v_voltage_i = self.get_all_voltage()
            self.add_to_dictionary(v_dict_voltage,dict_voltage_i)
            v_voltage_yearly.extend(v_voltage_i)            
            self.extract_period(v_voltage_i,v_voltage_period,i,end_index,num_periods)
            #Get power
            dict_power_i, v_power_i = self.get_all_power()
            v_power_yearly.extend(v_power_i)
            v_power_period=self.extract_period(v_power_i,v_power_period,i,end_index,num_periods)
            #Get loading
            dict_loading_i, v_loading_i,dict_buses_element = self.get_all_loading()
            self.add_to_dictionary(v_dict_loading,dict_loading_i)
            v_loading_yearly.extend(v_loading_i)
            v_loading_period=self.extract_period(v_loading_i,v_loading_period,i,end_index,num_periods)
            #Get dict losses
            dict_losses_i, v_losses_i = self.get_all_losses()
            self.add_to_dictionary(v_dict_losses,dict_losses_i)
            #Get losses
            subs_losses_i = self.get_total_subs_losses()
            v_subs_losses_yearly.append(subs_losses_i)
            line_losses_i = self.get_total_line_losses()
            v_line_losses_yearly.append(line_losses_i)
            #Print progress
            #percentage_str="{:.0f}".format(100*i/end_index)+"%"
            #if (percentage_str!=old_percentage_str):
            #    print(percentage_str)
            #old_percentage_str=percentage_str
        return v_dict_voltage,v_voltage_yearly,v_voltage_period,v_power_yearly,v_power_period,v_dict_loading,v_loading_yearly,v_loading_period,v_dict_losses,v_subs_losses_yearly,v_line_losses_yearly,dict_buses_element



import opendssdirect as dss       
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import sys as sys
import math
import networkx as nx

class OpenDSS_Interface:
    def __init__(self, folder,b_numeric_ids):
        """Initialices the folder variables"""
        self.main_folder = folder
        self.folder=folder+'/Validation'
        self.b_numeric_ids=b_numeric_ids

    def remove_terminal(self,bus):
        """Removes the terminal from the bus name"""
        if isinstance(bus,str):
            return bus.split('.')[0] #(everything to the right of point ".")
        else:
            return bus

    def is_to_be_analyzed(self,name):
        """Determines if an element has to be analyzed"""
        b_analyzed=False
        if name.startswith('Line.padswitch'): #RNM specific #We only condider power lines and tarnsformers as branches
            b_analyzed=False
        elif name.startswith('Line.breaker'): #RNM specific
            b_analyzed=False
        elif name.startswith('Line.fuse'): #RNM specific
            b_analyzed=False
        elif name.startswith('Capacitor'):
            b_analyzed=False
        elif name.startswith('Line.l'): #RNM specific
            b_analyzed=True
        elif name.startswith('Transformer'):
            b_analyzed=True
        else:
            print("Component type was not explicitly consiered in the validation module. It is not analyzed.")
            print(name)
        return b_analyzed



    def extract_period(self,v_value_i,v_value_period,i,end_index,num_periods):
        """Extracts period "i" out of "num_periods" from the whole gieve series (v_value_i)"""
        #It is assumes all the periods have the same length
        for j in range(num_periods):
            if (i<=end_index*(j+1)/num_periods):
                v_value_period[j].extend(v_value_i)
                break
        return v_value_period

    def add_to_dictionary(self,dict_all,dict_i):
        """Adds dict_i to the dictonary dict_all"""
        for idx,name in enumerate(dict_i):
            if name in dict_all: #if not empty
                dict_all[name].append(dict_i[name])
            else:
                dict_all[name]=[dict_i[name]]

    def dss_run_command(self,command):
        """Runs an OpenDSS Direct command"""
        #Run command
        output=dss.run_command(command)
        #If it has any output, print it
        if (len(output)>0):
            print(output)


    def get_all_voltage(self):
        """Computes over and under voltages for all buses"""
        #Get bus names
        bus_names = dss.Circuit.AllBusNames()
        #Init variables
        dict_voltage = {}
        v_voltage = [0 for _ in range(len(bus_names))]
        #For each bus
        for idx,b in enumerate(bus_names):
            #Set it as active bus
            dss.Circuit.SetActiveBus(b)
            #Get voltage and angle
            vang = dss.Bus.puVmagAngle()
            #Get voltage magnitude
            if len(vang[::2]) > 0:
                #Average of the voltages in all the phases, discarding the angles
                vmag = sum(vang[::2])/(len(vang)/2)  
            else:
                vmag = 0
            #Add voltage magnitude to dictionary and to list of voltages
            dict_voltage[b] = vmag
            v_voltage[idx]=vmag

        return dict_voltage,v_voltage


    def get_all_unbalance(self):
        """Computes voltage unbalance for all buses"""
        # Based on  IEEE standard 141-1993 https://www.sciencedirect.com/science/article/pii/S0378779620304594
        #Get bus names
        bus_names = dss.Circuit.AllBusNames()
        #Init variables
        dict_voltage = {}
        v_voltage = [0 for _ in range(len(bus_names))]
        #For each bus
        for idx,b in enumerate(bus_names):
            dss.Circuit.SetActiveBus(b)
            #Set it as active bus
            #Get voltage and angle
            vang = dss.Bus.puVmagAngle()
            #Evaluate the unbalance
            if len(vang[::2]) ==3: #if three-phase
                vmedio = sum(vang[::2])/(len(vang)/2) #Average of the voltages in all the phases, discarding the angles
                va=vang[0]  #Phase A
                vb=vang[2]  #Phase B
                vc=vang[4]  #Phase C
                vmax=max(abs(va-vmedio),abs(vb-vmedio),abs(vc-vmedio)) #Phase Voltage Unbalance Rate (PVUR)  (based on IEEE)
            elif len(vang[::2]) ==2: #If two phase
                vmedio = sum(vang[::2])/(len(vang)/2) #Average of the voltages in all the phases, discarding the angles
                va=vang[0]  #Phase A
                vb=vang[2]  #Phase B
                vmax=max(abs(va-vmedio),abs(vb-vmedio)) #Phase Voltage Unbalance Rate (PVUR)  
            elif len(vang[::2]) ==1: #If single-phase
                vmax = 0    #No unblance
            else: #Not other cases are considered
                print("Value: "+str(vang)+"Lend: "+str(len(vang)))
                raise Exception("Voltage is not single-, two- or three-phase")
            #Add unbalance to dictionary and to list of unbalances
            dict_voltage[b] = vmax
            v_voltage[idx]=vmax
        return dict_voltage,v_voltage


    def get_all_loads(self):
        """Get all loads peak kW and kVAr"""
        #Init variables
        dict_loads = {}        
        myrange=range(0,dss.Loads.Count())
        v_loads_kw = [0 for _ in myrange]
        v_loads_kvar = [0 for _ in myrange]
        #For each load
        for idx in myrange:
            #Set load index
            dss.Loads.Idx(idx+1)
            #Get kW of the load
            kw = dss.Loads.kW()
            #Get kVAr of the load
            kvar = dss.Loads.kvar()
            #Get load name
            name = 'LOAD.'+dss.Loads.Name()
            #Add load to dictionary and to list of load kW/kVAr
            dict_loads[name] = kw
            v_loads_kw[idx]=kw
            v_loads_kvar[idx]=kvar
        return dict_loads,v_loads_kw,v_loads_kvar

    def get_all_loadshapes(self,i):
        """Get all loadshapes"""
        dict_loads = {}
        #Init variables
        myrange=range(0,dss.LoadShape.Count())
        v_loads_kw = [0 for _ in myrange]
        v_loads_kvar = [0 for _ in myrange]
        #For each loadshape
        for idx in myrange:
            #Set loadshape index
            dss.LoadShape.Idx(idx+1)
            #Get hourly kW
            kw = dss.LoadShape.PMult()
            #Get hourly kVAr
            kvar = dss.LoadShape.QMult()
            #Get load name
            name = 'LOAD.'+dss.LoadShape.Name()
            #If not default load (discard it)
            if not(name=='LOAD.default'):
                if len(kw)>1:
                    #Add load to dictionary and to list of load kW
                    dict_loads[name] = kw[i]
                    v_loads_kw[idx]=kw[i]
                if len(kvar)>1:
                    #Add to list of load kW
                    v_loads_kvar[idx]=kvar[i]

        return dict_loads,v_loads_kw,v_loads_kvar


    def get_all_buses_loads(self,i):
        """Get the load of all the buses"""
        #Get data from load shapes
        dict_loads,v_loads_kw,v_loads_kvar=self.get_all_loadshapes(i)
        #Get all bus names
        bus_names = dss.Circuit.AllBusNames()
        #Init dict
        dict_buses_loads = {}
        #For each bus
        for idx,b in enumerate(bus_names):
            #Set it to the active bus
            dss.Circuit.SetActiveBus(b)
            #Get its loads
            loads = dss.Bus.LoadList()
            #Init its load to zero
            load_bus=0
            #For each load in the bus
            for l in loads:
                #Assign it the load in the loadshape
                load_bus=load_bus+dict_loads[l+"_profile"] #RNM-US specific (the load shapes names are the name of the laods + "_profile")
            #Add to dictionary
            dict_buses_loads[b] = load_bus
        return dict_buses_loads,v_loads_kw,v_loads_kvar


    def get_all_buses_ids(self):
        """Get the load of all the buses"""
        #Get all bus names
        bus_names = dss.Circuit.AllBusNames()
        #Init dict
        dict_buses_ids = {}
        dict_ids_buses = {}
        #Init numeric identifier
        num_id=1
        #For each bus
        for idx,b in enumerate(bus_names):
            if b=='st_mat': #RNM-US specific (st_mat is the slack bus)
                dict_buses_ids[b] = str(0)
                dict_ids_buses[str(0)] = b
            else:
                dict_buses_ids[b] = str(num_id)
                dict_ids_buses[str(num_id)] = b
                num_id=num_id+1
        return dict_buses_ids,dict_ids_buses

    def get_all_lines(self):
        """Gets the normal ampacity of power lines"""
        #Init variables
        dict_lines = {}
        myrange=range(0,dss.Lines.Count())
        v_lines_norm_amps = []
        #For each power line
        for idx in myrange:
            #Set power line index
            dss.Lines.Idx(idx+1)
            #Get the normal amapcity
            normal_amps = dss.Lines.NormAmps()
            #Get the power line name
            name = 'Line.'+dss.Lines.Name()
            #If it is a power line
            if name.startswith("Line.l("): #RNM-US specific (all power lines start with "Line.l("). This discards for example fuses, switches, ....
                #Add to dictionary and to list
                dict_lines[name] = normal_amps
                v_lines_norm_amps.append(normal_amps)

        return dict_lines,v_lines_norm_amps

    def get_all_transformers(self):
        """Gets the size of transformers"""
        #Init variables
        dict_transformers = {}
        myrange=range(0,dss.Transformers.Count())        
        v_transformers_kva = []
        #For each transformer
        for idx in myrange:
            #Set the transformer index
            dss.Transformers.Idx(idx+1)
            #Get the transformer size in kVA
            kva = dss.Transformers.kVA()
            #Get the transformer size
            name = 'Transformer.'+dss.Transformers.Name()
            #If it is a distribution transformer
            if name.startswith("Transformer.tr("): #Distribution transformer, RNM-US specific (all distribution transformers start with "Transformer.tr("). This discards for example transformers in primary substations
                #Add to dictionary and to list
                dict_transformers[name] = kva
                v_transformers_kva.append(kva)
        return dict_transformers,v_transformers_kva


    def get_all_power(self):
        """Computes power in all circuits (not used, loading is measured instead)"""
        #Get all element names
        circuit_names = dss.Circuit.AllElementNames()
        #Init variables
        dict_power = {}
        v_power = [0 for _ in range(len(circuit_names))]
        #For each circuit
        for idx,b in enumerate(circuit_names):
            #Set the active element
            dss.Circuit.SetActiveElement(b)
            #Calculates the power through the circuit
            power = dss.CktElement.Powers()
            if len(power[::2]) > 0:
                poweravg = sum(power[::2])/(len(power)/2)
            else:
                poweravg = 0
            #Add to dictionary and to list
            dict_power[b] = poweravg
            v_power[idx]=poweravg

        return dict_power,v_power


    def get_all_loading(self):
        """Computes loading in all circuits"""
        #Get all element names
        circuit_names = dss.Circuit.AllElementNames()
        #Init variables
        dict_loading = {}
        dict_buses_element={} #Associate the element to the buses (this has the inconvenient that only associates one element to each pair of buses)
        v_loading = [0 for _ in range(len(circuit_names))]
        #For each circuit
        for idx,element in enumerate(circuit_names):
            #Set the active element
            dss.Circuit.SetActiveElement(element)
            #Get the buses in the elment
            buses = dss.CktElement.BusNames()
            #Evaluate only if it is a branch (two buses)
            if (len(buses)>=2): 
                #Obtain the current through the element
                current = dss.CktElement.CurrentsMagAng()
                #Obtain the number of terminals
                num_terminals=dss.CktElement.NumTerminals()
                #Obtain the current magnitude (first terminal only, because in transformers NormalAmps gives the normal ampacity of the first winding) (to compare the same magnitudes)
                currentmag = current[0]
                #Obtain the normal amapcity
                nominal_current = dss.CktElement.NormalAmps()
                #Transformers have applied a 1.1 factor in the calculation of NormalAmps
                #See library that OpenDSSdirect uses in https://github.com/dss-extensions/dss_capi/blob/master/src/PDElements/Transformer.pas
                #in particular line code: AmpRatings[i] := 1.1 * kVARatings[i] / Fnphases / Vfactor;
                #Remove (do not use) the 1.1 margin set in the library to the nominal current
                if (element.startswith("Transformer")):
                    nominal_current=nominal_current/1.1 
                #If the element is to be analyzed and has a nominal current (this discards vsources)
                if (nominal_current>0  and self.is_to_be_analyzed(element)):
                    #Add to dictionaries and to vector
                    dict_loading[element] = currentmag/nominal_current 
                    v_loading[idx]=currentmag/nominal_current                            
                    bus1to2=self.remove_terminal(buses[0])+'-->'+self.remove_terminal(buses[1])
                    dict_buses_element[bus1to2]=element
        return dict_loading,v_loading,dict_buses_element

    def get_all_losses(self):
        """Computes losses in all circuits"""
        #Get all element names
        circuit_names = dss.Circuit.AllElementNames()
        #Init variables
        dict_losses = {}
        v_losses = [0 for _ in range(len(circuit_names))]
        total_losses=0
        #For each element
        for idx,element in enumerate(circuit_names):
            #Set it as active element
            dss.Circuit.SetActiveElement(element)
            #Get buses names in element
            buses = dss.CktElement.BusNames()
            #only if it is a branch (two buses)
            if (len(buses)>=2): 
                #Get nominal current
                nominal_current = dss.CktElement.NormalAmps()
                #If it has nominal current (this discards vsources)
                if (nominal_current>0):
                    #Get hte losses
                    losses = dss.CktElement.Losses()
                    if len(losses) ==2:
                        lossesavg = (losses[0]) #[0] to take active losses
                    else:
                        print("Error - not correctly reading losses")
                        lossesavg=0          
                    #Convert to kW (becase CktElement.Losses is the exeption that return losses in W)
                    lossesavg=lossesavg/1000 
                    #If element is to be analized
                    if self.is_to_be_analyzed(element):
                        #Add to dictionary an to list
                        dict_losses[element] = lossesavg
                        v_losses[idx]=lossesavg        
        return dict_losses,total_losses

    def get_total_subs_losses(self):
        """Computes total substation losses"""
        return dss.Circuit.SubstationLosses()[0]  #Real part

    def get_total_line_losses(self):
        """Computes total power line losses"""
        return dss.Circuit.LineLosses()[0] #Real part

    def get_edges(self,v_dict_buses_ids):
        """Gets the edges of the distribution system (to obtain the graph of the network)"""
        #Get all element names
        circuit_names = dss.Circuit.AllElementNames()
        #Init variable
        closed_edges=[]
        open_edges=[]
        #For all elements
        for idx,element in enumerate(circuit_names):
            #Set it as active element
            dss.Circuit.SetActiveElement(element)
            #Get the bus names
            buses = dss.CktElement.BusNames()
            #Only if it is a branch
            if (len(buses)>=2): #There can be 3 buses in single-phase center-tap transformer, in this case the two last ones are equals (different terminals only) and we can take just the 2 first ones
                #Avoid cases bus1=bus2 (after removing terminals)
                if (self.remove_terminal(buses[0])!=self.remove_terminal(buses[1])):
                    #Identify if enabled #RNM-US specific (open loops are modelled with enabled=n)                
                    b_enabled=dss.CktElement.Enabled()
                    #if Enabled (i.e. it it is closed)
                    if (b_enabled):
                        #Add to edges
                        #remove terminal from the bus name (everything to the right of point)
                        #closed_edges.append([(self.remove_terminal(buses[0]),self.remove_terminal(buses[1]))])                
                        if (self.b_numeric_ids):
                            closed_edges.append((v_dict_buses_ids[self.remove_terminal(buses[0])],v_dict_buses_ids[self.remove_terminal(buses[1])]))                
                        else:
                            closed_edges.append((self.remove_terminal(buses[0]),self.remove_terminal(buses[1])))                
                    elif (not b_enabled): #if not Enabled (i.e. it it is open)
                        #open_edges.append([(self.remove_terminal(buses[0]),self.remove_terminal(buses[1]))])                
                        if (self.b_numeric_ids):
                            open_edges.append((v_dict_buses_ids[self.remove_terminal(buses[0])],v_dict_buses_ids[self.remove_terminal(buses[1])]))                
                        else:
                            open_edges.append((self.remove_terminal(buses[0]),self.remove_terminal(buses[1])))                
        return closed_edges,open_edges



    def is_violation(self,value,v_range):
        """Obtain number of violations (hours) of a bus"""
        #Init to zero
        num=0
        #If out of range
        if value<v_range['allowed_range'][0] or value>=v_range['allowed_range'][1]:
            num=1 #Number of violations=1        
        else: #Else
            num=0 #Number of violations=0        
        return num



    def get_num_violations(self,v_value,v_range,name,dict_loads):
        """"Obtain number of violations (hours) of a bus"""
        #Init to zero
        num_violations=0
        #For each value
        for idx2,value in enumerate(v_value):  
            #If no dict of loads, add 1 if there is a violation in that value (if it is outside of the allowed range)
            if (dict_loads is None):
                num_violations=num_violations+self.is_violation(value,v_range)
            #If there is a dict of loads
            elif (name in dict_loads):
                if (dict_loads[name][idx2]>0): #only compute if there is load
                    #If there is a vioaltion, add the load (to compute the energy delivered with violations)
                    num_violations=num_violations+self.is_violation(value,v_range)*dict_loads[name][idx2]
        return num_violations


    def write_dict(self,subfolder,v_dict,v_range,type,component,v_dict_buses_ids):
        """Writes the dictionary to a file"""
        #Path and file name
        output_file_full_path = self.folder + '/' + subfolder + '/' + type + '_' + component + '.csv'
        # Write directly as a CSV file with headers on first line
        with open(output_file_full_path, 'w') as fp:
            #Header: ID, hours 
            for idx,name in enumerate(v_dict):
                if (self.b_numeric_ids):
                    fp.write('Num. ID,bus/'+'Hour,'+','.join(str(idx2) for idx2,value in enumerate(v_dict[name])) + '\n')
                else:
                    fp.write('Hour,'+','.join(str(idx2) for idx2,value in enumerate(v_dict[name])) + '\n')
                break
            #Write matrix
            for idx,name in enumerate(v_dict):
                #Init list
                truncated_values=[]
                #For each one
                for idx2,value in enumerate(v_dict[name]):                      
                    #if it is outsie of the allowed range
                    if not(v_range['allowed_range']) or value<v_range['allowed_range'][0] or value>=v_range['allowed_range'][1]:
                        truncated_values.append("{:.7f}".format(value)) #Add the value
                    else: #else
                        truncated_values.append("")         #Fill with an empty variable
                #Write to file
                if v_dict_buses_ids is None or not self.b_numeric_ids:
                    fp.write(name+','+','.join(truncated_values)+'\n')
                else:
                    fp.write(str(v_dict_buses_ids[name])+','+name+','+','.join(truncated_values)+'\n')


    def write_id_dict(self,subfolder,type,v_dict_buses_ids):
        """Writes the dictionary to a file"""
        #Path and file name
        output_file_full_path = self.folder + '/' + subfolder + '/' + type + '.csv'
        # Write directly as a CSV file with headers on first line
        with open(output_file_full_path, 'w') as fp:
            #Header: ID, bus
            fp.write('Num. ID,bus' + '\n')
            for idx,name in enumerate(v_dict_buses_ids):
                fp.write(str(v_dict_buses_ids[name])+','+name+'\n')


    def solve_powerflow_iteratively(self,num_periods,start_index,end_index,location,v_range_voltage,v_range_loading,v_range_unbalance):
        """Solves the power flow iteratively"""
        #Por flow solving mode (hourly)
        self.dss_run_command("Clear")
        self.dss_run_command('Redirect '+location)
        self.dss_run_command("solve mode = snap")
        self.dss_run_command("Set mode=yearly stepsize=1h number=1")
        #Init vectors
        v_voltage_yearly=[]                                 #Yearly votlage
        v_voltage_period=[[] for _ in range(num_periods)]   #Montly voltage
        v_unbalance_yearly=[]                               #Yearly unbalance
        v_unbalance_period=[[] for _ in range(num_periods)] #Monthly unbalance
        v_power_yearly=[]                                   #Yearly power
        v_power_period=[[] for _ in range(num_periods)]     #Montly pwoer
        v_loading_yearly=[]                                 #Yearly loading
        v_loading_period=[[] for _ in range(num_periods)]   #Montly loading
        v_subs_losses_yearly=[]                             #Yearly substation losses
        v_line_losses_yearly=[]                             #Yearly power line losses
        v_loads_kw_yearly=[]                                #Yearly kW of loads (for violing plots)
        v_loads_kw_period=[[] for _ in range(num_periods)]  #Montly kW of loads (for violing plots)    
        v_loads_kvar_yearly=[]                              #Yearly kVAr of loads (for violing plots)
        v_loads_kvar_period=[[] for _ in range(num_periods)]#Montly kVAr of loads (for violing plots)
        v_total_load_kw_yearly=[]                           #Yearly total kW of loads (for duration curve)
        v_total_load_kvar_yearly=[]                         #Yearly total kVAr of loads (for duration curve)
        v_dict_voltage={}                                   #Dict of voltages
        v_dict_unbalance={}                                 #Dict of unbalances
        v_dict_loading={}                                   #Dict of loading
        v_dict_losses={}                                    #Dict of losses
        v_dict_loads={}                                     #Dict of loads
        #Additional initializations
        my_range=range(start_index,end_index,1)             #Full year
        old_percentage_str="" #Variable for tracking progress
        #Get buses ids
        v_dict_buses_ids,v_dict_ids_buses=self.get_all_buses_ids()
        #For each hour
        for i in my_range:
            #Solve power flow in that hour
            self.dss_run_command("Solve")
            #Get voltages
            dict_voltage_i, v_voltage_i = self.get_all_voltage()
            self.add_to_dictionary(v_dict_voltage,dict_voltage_i)
            v_voltage_yearly.extend(v_voltage_i)            
            v_voltage_period=self.extract_period(v_voltage_i,v_voltage_period,i,end_index,num_periods)
            #Get voltage unbalance
            dict_unbalance_i, v_unbalance_i = self.get_all_unbalance()
            self.add_to_dictionary(v_dict_unbalance,dict_unbalance_i)
            v_unbalance_yearly.extend(v_unbalance_i)            
            v_unbalance_period=self.extract_period(v_unbalance_i,v_unbalance_period,i,end_index,num_periods)
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
            #Get loads shapes
            dict_loads_i, v_loads_kw_i, v_loads_kvar_i= self.get_all_buses_loads(i)
            self.add_to_dictionary(v_dict_loads,dict_loads_i)
            v_loads_kw_yearly.extend(v_loads_kw_i)            
            v_loads_kw_period=self.extract_period(v_loads_kw_i,v_loads_kw_period,i,end_index,num_periods)
            v_loads_kvar_yearly.extend(v_loads_kvar_i)            
            v_loads_kvar_period=self.extract_period(v_loads_kvar_i,v_loads_kvar_period,i,end_index,num_periods)
            #Get total peak load
            v_total_load_kw_yearly.append(sum(v_loads_kw_i))
            v_total_load_kvar_yearly.append(sum(v_loads_kvar_i))
            #Print progress (disabled because the Ruby gem does not output the print messages)
            #percentage_str="{:.0f}".format(100*i/end_index)+"%"
            #if (percentage_str!=old_percentage_str):
            #    print(percentage_str)
            #old_percentage_str=percentage_str
        #Get loads shapes
        dict_loads, v_loads_kw, v_loads_kvar= self.get_all_buses_loads(i)
        #Get lines normal amps
        dict_lines,v_lines_norm_amps=self.get_all_lines()
        #Get transformers size
        dict_transformers,v_transformers_kva=self.get_all_transformers()
        return v_dict_buses_ids,v_dict_ids_buses,v_dict_voltage,v_voltage_yearly,v_voltage_period,v_power_yearly,v_power_period,v_dict_loading,v_loading_yearly,v_loading_period,v_dict_losses,v_subs_losses_yearly,v_line_losses_yearly,dict_buses_element,v_dict_loads,v_loads_kw_yearly,v_loads_kw_period,v_loads_kvar_yearly,v_loads_kvar_period,v_total_load_kw_yearly,v_total_load_kvar_yearly, v_loads_kw, v_loads_kvar,v_dict_unbalance,v_unbalance_yearly,v_unbalance_period,dict_lines,v_lines_norm_amps,dict_transformers,v_transformers_kva



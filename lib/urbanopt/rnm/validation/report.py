import opendss_interface
import numpy as np

class Report:
    def __init__(self, folder,b_numeric_ids):
        """Initialices the folder variables"""
        self.main_folder = folder
        self.folder=folder+'/Validation'
        self.num_top_violations=5
        self.b_numeric_ids=b_numeric_ids
        
    def is_to_be_analyzed(self,name,label_type):
        """Determines if a network component has to be analyzed in the report"""
        b_analyzed=False
        if label_type=='All':
            b_analyzed=True
        elif not isinstance(name, str):
            b_analyzed=True
        elif name.startswith('Line.padswitch'): #RNM-US specific nomenclature #We only condider power lines and tarnsformers as branches
            b_analyzed=False
        elif name.startswith('Line.breaker'): #RNM-US specific nomenclature
            b_analyzed=False
        elif name.startswith('Line.fuse'): #RNM-US specific nomenclature
            b_analyzed=False
        elif name.startswith('Capacitor'):
            b_analyzed=False
        elif label_type=="LineTransformer":
            if (name.startswith("Line.l") or name.startswith("Transformer")): #RNM-US specific nomenclature
                b_analyzed=True
        elif label_type=="Line" and name.startswith('Line.l'): #RNM-US specific nomenclature
            b_analyzed=True
        elif label_type=="Transformer" and name.startswith('Transformer'):
            b_analyzed=True
        elif name.startswith(label_type):
            b_analyzed=True
        return b_analyzed

    def get_dict_num_violations(self,v_dict_voltage,v_range,label_type,dict_loads):
        """Obtains the number of violations (hours) of each bus"""
        myopendss_io=opendss_interface.OpenDSS_Interface(self.folder,self.b_numeric_ids)
        dic_num_violations_v={}
        for name in v_dict_voltage:
            if self.is_to_be_analyzed(name,label_type):
                dic_num_violations_v[name]=myopendss_io.get_num_violations(v_dict_voltage[name],v_range,name,dict_loads)
        return dic_num_violations_v

    def transpose_dic(self,v_dict,label_type):
        """Transpose (t) the dict"""
        #e.g. Instead of buses in rows and hours in columns, it puts hours in rows and buses in columns
        keys = v_dict.keys()
        matrix = [v_dict[i] for i in keys if self.is_to_be_analyzed(i,label_type)]
        matrix_t={idx:list(i) for idx,i in enumerate(zip(*matrix))}
        return matrix_t

    def len(self,v_dict,label_type,dict_loads):
        """Obtains the number of elements in a dict vector (used to compute percentages)"""
        #Init to zero
        num=0
        #For each key
        for i in v_dict.keys():
            #If element t is to be analyzed
            if self.is_to_be_analyzed(i,label_type):
                #If there is no dictionary of loads, or if the load is in the dictionary
                if (dict_loads is None or i in dict_loads):
                    num=num+1 #Add 1
        return num

    def size(self,v_dict,label_type,dict_loads):
        """Obtains the number of elements in a dict matrix (used to compute percentages)"""
        #Init to zero
        num=0
        #For each key
        for i in v_dict.keys():
            #If element t is to be analyzed
            if self.is_to_be_analyzed(i,label_type):
                #For each hour
                for idx,j in enumerate(v_dict[i]):
                    if (dict_loads is None): #If there is no dictionary of loads
                         num=num+1  #Add 1
                    elif (i in dict_loads): #if the load is in the dictionary (there is a dictionary of loads when the energy is being evaluated)
                        num=num+dict_loads[i][idx] #Add the energy in that hour
        return num


    def count_nonzero(self,dict,label_type,dict_loads):
        """Counts non zero elements (to identify number of violations)"""
        #Init to zero
        num=0
        #For each key
        for i in dict:
            #If it is not zero
            if dict[i]!=0:
                #If the element is to be analyzed
                if self.is_to_be_analyzed(i,label_type):
                    #If there is no dictionary of loads, or if the load is in the dictionary
                    if (dict_loads is None or i in dict_loads):
                        num=num+1 #Add 1
        return num

    def sum(self,dict,label_type,dict_loads):
        """It sums all the values in the dict of the elements to be analyzed"""
        #Init to zero
        num=0
        #For each key
        for i in dict:
            #If the element is to be analyzed
            if self.is_to_be_analyzed(i,label_type):
                #If there is no dictionary of loads, or if the load is in the dictionary
                if (dict_loads is None or i in dict_loads):
                    num=num+dict[i] #Add the value in the dict
        return num

    def get_top_violations(self,v_dict,label_type):
        """Get the top violations (the elements that have the highest number of violations)"""
        #Sort the vioations
        sorted_violations=dict(sorted(v_dict.items(), key=lambda item: item[1],reverse=True))
        #Init the variables
        top_violations={} 
        num=0
        #For each violation
        for name in sorted_violations:
            #Only the num_elements top, and only if they have violations
            if (num<=self.num_top_violations and sorted_violations[name]>0):
                #If the element is to be analyzed
                if self.is_to_be_analyzed(name,label_type):
                    top_violations[name]=sorted_violations[name]
                    num=num+1
        return top_violations

    def get_stats(self,v_dict,v_range,label_type,dict_loads):
        """Obtains all the stats required to calculate a given metric"""
        #Get dict of violations in each element
        violations=self.get_dict_num_violations(v_dict,v_range,label_type,dict_loads)
        #Top violations
        top_violations=self.get_top_violations(violations,label_type)
        #Number of elements with some violations
        num_violations=self.count_nonzero(violations,label_type,dict_loads)
        #Number of elements
        pc_violations=num_violations/self.len(violations,label_type,dict_loads)
        #Number of elements x hour with a violation
        sum_violations=self.sum(violations,label_type,dict_loads)
        #Number of elements x hour
        pc_sum_violations=sum_violations/self.size(v_dict,label_type,dict_loads)
        return num_violations,pc_violations,sum_violations,pc_sum_violations,top_violations


    def assess_metric(self,v_dict,v_range,dict_metrics,label_component,label_violation,label_type,b_hours,dict_loads):
        """Obtains an individual metric"""
        #Get required stats to calculate the metric
        num_violations,pc_violations,sum_violations,pc_sum_violations,top_violations=self.get_stats(v_dict,v_range,label_type,dict_loads)
        #Check that dict is not empty
        if dict_loads is None:
            #Assign labels
            #For the function calculating the metrics it is needed to specify that it is only lines and transformers, but for label we can call it just "All"            
            if (label_type)=="LineTransformer":
                label_type="All"
            if not b_hours:
                label=label_component+'_'+label_violation
            else:
                label='Hours'+'_'+label_violation
            if label_violation=='Loading':
                mylabel1='Num_'+label+'_Violations_'+label_type #e.g. number of buses with voltage violations
                mylabel2='Percentage_'+label+'_Violations_'+label_type+'(%)'
            else:
                mylabel1='Num_'+label+'_Violations' #e.g. number of buses with voltage violations
                mylabel2='Percentage_'+label+'_Violations(%)'
            #Evaluate number and percentage of violations of the element
            dict_metrics[mylabel1]=num_violations
            dict_metrics[mylabel2]=pc_violations*100
            #Optionally print them in the console
            #print(mylabel1+': '+str(num_violations))
            #print(mylabel2+': '+'{:.1f}'.format(pc_violations*100))
        #If we are not evluating hours (for hours we do not evaluate the number of element x hour violations, because we have already calculated it for the elements)
        if not b_hours:
            #Assign labels
            if dict_loads is None:
                label='('+label_component+'_x_Hours)_'+label_violation
            else:
                label='Energy_kWh_'+label_violation
            if label_violation=='Loading':
                mylabel3='Num_'+label+'_Violations_'+label_type #e.g. number of buses*hours with voltage violations (it is the same calculated with hours and with buses)
                mylabel4='Percentage_'+label+'_Violations_'+label_type+'(%)'
            else:
                mylabel3='Num_'+label+'_Violations' #e.g. number of buses*hours with voltage violations (it is the same calculated with hours and with buses)
                mylabel4='Percentage_'+label+'_Violations(%)'
            #Evalute number and percentage of violations of elements x hours
            dict_metrics[mylabel3]=sum_violations
            dict_metrics[mylabel4]=pc_sum_violations*100
            #Optionally print them in the console
            #print(mylabel3+': '+str(sum_violations))
            #print(mylabel4+': '+'{:.1f}'.format(pc_sum_violations*100))
        return dict_metrics,top_violations

    def assess_metrics(self,v_dict,v_range,dict_metrics,label_component,label_violation,label_type,dict_loads):
        """Asseses all the metrics (elements (bus/branch), hours, or elements x hour) of a given type (voltage, unbalance or loading)"""
        #Evaluate the metric of the element
        dict_metrics,top_violations=self.assess_metric(v_dict,v_range,dict_metrics,label_component,label_violation,label_type,False,None)
        #Evaluete the energy delivered with violations (only for voltages)
        if ('voltage' in label_violation.lower() or 'unbalance' in label_violation.lower()):
           dict_metrics,discard=self.assess_metric(v_dict,v_range,dict_metrics,label_component,label_violation,label_type,False,dict_loads)
        #We transpose it to analyze hours instead of buses
        v_dic_hours_violations=self.transpose_dic(v_dict,label_type)
        #We evaluate the metric again, now for the hours
        dict_metrics,discard=self.assess_metric(v_dic_hours_violations,v_range,dict_metrics,label_component,label_violation,label_type,True,None)
        return dict_metrics,top_violations

    def get_metrics(self,v_dict_voltage,v_range_voltage,v_dict_unbalance,v_range_unbalance,v_dict_loading,v_range_loading,dict_loads):
        """Calculates all the metrics"""
        dict_metrics={}
        #Voltage
        dict_metrics,top_buses_voltage=self.assess_metrics(v_dict_voltage,v_range_voltage,dict_metrics,'Buses','Voltage','All',dict_loads)
        #Under-Voltage
        v_range_voltage_under=dict(v_range_voltage)
        v_range_voltage_under['allowed_range']=(v_range_voltage['allowed_range'][0],float('inf'))
        dict_metrics,top_buses_under=self.assess_metrics(v_dict_voltage,v_range_voltage_under,dict_metrics,'Buses','Under-voltage','All',dict_loads)
        #Over-Voltage
        v_range_voltage_over=dict(v_range_voltage)
        v_range_voltage_over['allowed_range']=(0,v_range_voltage['allowed_range'][1])
        dict_metrics,top_buses_over=self.assess_metrics(v_dict_voltage,v_range_voltage_over,dict_metrics,'Buses','Over-voltage','All',dict_loads)
        #Unbalance
        dict_metrics,top_buses_unbalance=self.assess_metrics(v_dict_unbalance,v_range_unbalance,dict_metrics,'Buses','Unbalance','All',dict_loads)
        #Loading
        dict_metrics,top_branches_violations=self.assess_metrics(v_dict_loading,v_range_loading,dict_metrics,'Branches','Loading','LineTransformer',None)
        dict_metrics,top_lines_violations=self.assess_metrics(v_dict_loading,v_range_loading,dict_metrics,'Branches','Loading','Line',None)
        dict_metrics,top_transformers_violations=self.assess_metrics(v_dict_loading,v_range_loading,dict_metrics,'Branches','Loading','Transformer',None)
        return dict_metrics,top_buses_under,top_buses_over,top_buses_unbalance,top_lines_violations,top_transformers_violations


    def write_raw_metrics(self,dict_metrics,top_buses_under,top_buses_over,top_buses_unbalance,top_lines_violations,top_transformers_violations):
        """Writes a raw file with all the metrics"""
        #Path and file name
        output_file_full_path = self.folder + '/Summary/' + 'Raw_Metrics' + '.csv'
        #Open
        with open(output_file_full_path, 'w') as fp:
            #Write raw metrics
            for idx,name in enumerate(dict_metrics):
                fp.write(name+','+'{:.0f}'.format(dict_metrics[name])+'\n')
            #Top under-voltage violations
            fp.write('Top Under-Voltage Violations, ')
            for idx,name in enumerate(top_buses_under):
                fp.write(name+'('+'{:.0f}'.format(top_buses_under[name])+'h)')
                if idx != len(top_buses_under)-1:
                    fp.write(', ')
            fp.write('\n')
            #Top over-voltage violations
            fp.write('Top Over-Voltage Violations, ')
            for idx,name in enumerate(top_buses_over):
                fp.write(name+'('+'{:.0f}'.format(top_buses_over[name])+'h)')
                if idx != len(top_buses_over)-1:
                    fp.write(', ')

            fp.write('\n')
            #Top unbalance violations
            fp.write('Top Voltage Unbalance Violations, ')
            for idx,name in enumerate(top_buses_unbalance):
                fp.write(name+'('+'{:.0f}'.format(top_buses_unbalance[name])+'h)')
                if idx != len(top_buses_unbalance)-1:
                    fp.write(', ')
            fp.write('\n')
            #Top power line thermal limit violations
            fp.write('Top Power Line Thermal limit Violations, ')
            for idx,name in enumerate(top_lines_violations):
                fp.write(name+'('+'{:.0f}'.format(top_lines_violations[name])+'h)')
                if idx != len(top_lines_violations)-1:
                    fp.write(', ')
            fp.write('\n')
            #Top transformer thermal limit violations
            fp.write('Top Transformer Thermal limit Violations, ')
            for idx,name in enumerate(top_transformers_violations):
                fp.write(name+'('+'{:.0f}'.format(top_transformers_violations[name])+'h)')
                if idx != len(top_transformers_violations)-1:
                    fp.write(', ')
            fp.write('\n')

    def write_formatted_metrics(self,dict_metrics,top_buses_under,top_buses_over,top_buses_unbalance,top_lines_violations,top_transformers_violations):
        """Write formatted summary operational report, presenting all the metrics in an organized way"""
        #Path and file name
        output_file_full_path = self.folder + '/Summary/' + 'Summary_Operational_Report' + '.csv'
        #Open
        with open(output_file_full_path, 'w') as fp:
            #Voltage violations
            fp.write('Voltage violations\n')
            fp.write('Buses: ')
            fp.write(' Total '+'{:.0f}'.format(dict_metrics['Num_Buses_Voltage_Violations'])+'('+'{:.0f}'.format(dict_metrics['Percentage_Buses_Voltage_Violations(%)'])+'%)')
            fp.write(' Under '+'{:.0f}'.format(dict_metrics['Num_Buses_Under-voltage_Violations'])+'('+'{:.0f}'.format(dict_metrics['Percentage_Buses_Under-voltage_Violations(%)'])+'%)')
            fp.write(' Over '+'{:.0f}'.format(dict_metrics['Num_Buses_Over-voltage_Violations'])+'('+'{:.0f}'.format(dict_metrics['Percentage_Buses_Over-voltage_Violations(%)'])+'%)')
            fp.write('\n')
            fp.write('Hours: ')
            fp.write(' Total '+'{:.0f}'.format(dict_metrics['Num_Hours_Voltage_Violations'])+'('+'{:.0f}'.format(dict_metrics['Percentage_Hours_Voltage_Violations(%)'])+'%)')
            fp.write(' Under '+'{:.0f}'.format(dict_metrics['Num_Hours_Under-voltage_Violations'])+'('+'{:.0f}'.format(dict_metrics['Percentage_Hours_Under-voltage_Violations(%)'])+'%)')
            fp.write(' Over '+'{:.0f}'.format(dict_metrics['Num_Hours_Over-voltage_Violations'])+'('+'{:.0f}'.format(dict_metrics['Percentage_Hours_Over-voltage_Violations(%)'])+'%)')
            fp.write('\n')
            fp.write('(Buses x Hours): ')
            fp.write(' Total '+'{:.0f}'.format(dict_metrics['Num_(Buses_x_Hours)_Voltage_Violations'])+'('+'{:.0f}'.format(dict_metrics['Percentage_(Buses_x_Hours)_Voltage_Violations(%)'])+'%)')
            fp.write(' Under '+'{:.0f}'.format(dict_metrics['Num_(Buses_x_Hours)_Under-voltage_Violations'])+'('+'{:.0f}'.format(dict_metrics['Percentage_(Buses_x_Hours)_Under-voltage_Violations(%)'])+'%)')
            fp.write(' Over '+'{:.0f}'.format(dict_metrics['Num_(Buses_x_Hours)_Over-voltage_Violations'])+'('+'{:.0f}'.format(dict_metrics['Percentage_(Buses_x_Hours)_Over-voltage_Violations(%)'])+'%)')
            fp.write('\n')
            fp.write('Energy_kWh: ')
            fp.write(' Total '+'{:.0f}'.format(dict_metrics['Num_Energy_kWh_Voltage_Violations'])+'('+'{:.0f}'.format(dict_metrics['Percentage_Energy_kWh_Voltage_Violations(%)'])+'%)')
            fp.write(' Under '+'{:.0f}'.format(dict_metrics['Num_Energy_kWh_Under-voltage_Violations'])+'('+'{:.0f}'.format(dict_metrics['Percentage_Energy_kWh_Under-voltage_Violations(%)'])+'%)')
            fp.write(' Over '+'{:.0f}'.format(dict_metrics['Num_Energy_kWh_Over-voltage_Violations'])+'('+'{:.0f}'.format(dict_metrics['Percentage_Energy_kWh_Over-voltage_Violations(%)'])+'%)')
            fp.write('\n')
            fp.write('\n')
            #Unbalance violations
            fp.write('Voltage unbalance violations\n')
            fp.write('Buses: ')
            fp.write(' Total '+'{:.0f}'.format(dict_metrics['Num_Buses_Unbalance_Violations'])+'('+'{:.0f}'.format(dict_metrics['Percentage_Buses_Unbalance_Violations(%)'])+'%)')
            fp.write('\n')
            fp.write('Hours: ')
            fp.write(' Total '+'{:.0f}'.format(dict_metrics['Num_Hours_Unbalance_Violations'])+'('+'{:.0f}'.format(dict_metrics['Percentage_Hours_Unbalance_Violations(%)'])+'%)')
            fp.write('\n')
            fp.write('(Buses x Hours): ')
            fp.write(' Total '+'{:.0f}'.format(dict_metrics['Num_(Buses_x_Hours)_Unbalance_Violations'])+'('+'{:.0f}'.format(dict_metrics['Percentage_(Buses_x_Hours)_Unbalance_Violations(%)'])+'%)')
            fp.write('\n')
            fp.write('Energy_kWh: ')
            fp.write(' Total '+'{:.0f}'.format(dict_metrics['Num_Energy_kWh_Unbalance_Violations'])+'('+'{:.0f}'.format(dict_metrics['Percentage_Energy_kWh_Unbalance_Violations(%)'])+'%)')
            fp.write('\n')
            fp.write('\n')
            #Thermal limit violations
            fp.write('Thermal limit violations\n')
            fp.write('Branches: ')
            fp.write(' Total '+'{:.0f}'.format(dict_metrics['Num_Branches_Loading_Violations_All'])+'('+'{:.0f}'.format(dict_metrics['Percentage_Branches_Loading_Violations_All(%)'])+'%)')
            fp.write(' Lines '+'{:.0f}'.format(dict_metrics['Num_Branches_Loading_Violations_Line'])+'('+'{:.0f}'.format(dict_metrics['Percentage_Branches_Loading_Violations_Line(%)'])+'%)')
            fp.write(' Transformers '+'{:.0f}'.format(dict_metrics['Num_Branches_Loading_Violations_Transformer'])+'('+'{:.0f}'.format(dict_metrics['Percentage_Branches_Loading_Violations_Transformer(%)'])+'%)')
            fp.write('\n')
            fp.write('Hours: ')
            fp.write(' Total '+'{:.0f}'.format(dict_metrics['Num_Hours_Loading_Violations_All'])+'('+'{:.0f}'.format(dict_metrics['Percentage_Hours_Loading_Violations_All(%)'])+'%)')
            fp.write(' Lines '+'{:.0f}'.format(dict_metrics['Num_Hours_Loading_Violations_Line'])+'('+'{:.0f}'.format(dict_metrics['Percentage_Hours_Loading_Violations_Line(%)'])+'%)')
            fp.write(' Transformers '+'{:.0f}'.format(dict_metrics['Num_Hours_Loading_Violations_Transformer'])+'('+'{:.0f}'.format(dict_metrics['Percentage_Hours_Loading_Violations_Transformer(%)'])+'%)')
            fp.write('\n')
            fp.write('(Branches x Hours): ')
            fp.write(' Total '+'{:.0f}'.format(dict_metrics['Num_(Branches_x_Hours)_Loading_Violations_All'])+'('+'{:.0f}'.format(dict_metrics['Percentage_(Branches_x_Hours)_Loading_Violations_All(%)'])+'%)')
            fp.write(' Lines '+'{:.0f}'.format(dict_metrics['Num_(Branches_x_Hours)_Loading_Violations_Line'])+'('+'{:.0f}'.format(dict_metrics['Percentage_(Branches_x_Hours)_Loading_Violations_Line(%)'])+'%)')
            fp.write(' Transformers '+'{:.0f}'.format(dict_metrics['Num_(Branches_x_Hours)_Loading_Violations_Transformer'])+'('+'{:.0f}'.format(dict_metrics['Percentage_(Branches_x_Hours)_Loading_Violations_Transformer(%)'])+'%)')
            fp.write('\n')
            fp.write('\n')
            #Top violations
            fp.write('Top Under-Voltage Violations\n')
            for idx,name in enumerate(top_buses_under):
                fp.write(name+'('+'{:.0f}'.format(top_buses_under[name])+'h)')
                fp.write('\n')
            fp.write('\n')
            fp.write('Top Over-Voltage Violations\n')
            for idx,name in enumerate(top_buses_over):
                fp.write(name+'('+'{:.0f}'.format(top_buses_over[name])+'h)')
                fp.write('\n')
            fp.write('\n')
            fp.write('Top Unbalance Violations\n')
            for idx,name in enumerate(top_buses_unbalance):
                fp.write(name+'('+'{:.0f}'.format(top_buses_unbalance[name])+'h)')
                fp.write('\n')
            fp.write('\n')
            fp.write('Top Power Line Thermal limit Violations\n')
            for idx,name in enumerate(top_lines_violations):
                fp.write(name+'('+'{:.0f}'.format(top_lines_violations[name])+'h)')
                fp.write('\n')
            fp.write('\n')
            fp.write('Top Transformer Thermal limit Violations\n')
            for idx,name in enumerate(top_transformers_violations):
                fp.write(name+'('+'{:.0f}'.format(top_transformers_violations[name])+'h)')
                fp.write('\n')

    def write_summary_operational_report(self,subfolder,v_dict_voltage,v_range_voltage,v_dict_unbalance,v_range_unbalance,v_dict_loading,v_range_loading,v_dict_loads):
        """Calculate and write all the metrics and the summary operational report"""
        #Calculate all the metrics
        dict_metrics,top_buses_under,top_buses_over,top_buses_unbalance,top_lines_violations,top_transformers_violations=self.get_metrics(v_dict_voltage,v_range_voltage,v_dict_unbalance,v_range_unbalance,v_dict_loading,v_range_loading,v_dict_loads)
        #Write a file with the raw metrics
        self.write_raw_metrics(dict_metrics,top_buses_under,top_buses_over,top_buses_unbalance,top_lines_violations,top_transformers_violations)
        #Write a file with summary operational report
        self.write_formatted_metrics(dict_metrics,top_buses_under,top_buses_over,top_buses_unbalance,top_lines_violations,top_transformers_violations)

import opendssdirect as dss       
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import sys as sys
import math
import networkx as nx
import opendss_interface

class Plot_Lib:
    def __init__(self, folder):
        self.folder = folder

    def remove_terminal(self,bus):
        myopendss_io=opendss_interface.OpenDSS_Interface(self.folder)
        bus=myopendss_io.remove_terminal(bus)
        return bus


    def plot_hist(self,type,v_value,v_value_period,v_range,num_bins,num_periods,v_limits):
        output_file_full_path_fig = self.folder + '/' + type +  ' Histogram (p.u.).png'
        output_file_full_path_csv = self.folder + '/' + type + ' Histogram (p.u.).csv'
        plt.figure
        plt.grid(True)
        v_legend=["" for _ in range(num_periods+2)]
        matrix=np.empty((num_bins,num_periods+2)) #Matrix for writting to file (index+periods+yearly)
        for j in range(num_periods):
            plt.xlim(v_range)
            v_weights = np.ones_like(v_value_period[j]) / len(v_value_period[j])
            counts, bins = np.histogram(v_value_period[j], range=v_range, bins=num_bins, weights=v_weights)
            if j==0:
                v_legend[0]=type 
                matrix[:,0]=bins[:num_bins:]
            matrix[:,j+1]=counts
            v_legend[j+1]= "M"+str(j+1)
            plt.plot(bins[:-1]+(bins[1]-bins[0])*0.5, counts)

        v_weights = np.ones_like(v_value) / len(v_value)
        counts, bins = np.histogram(v_value, range=v_range, bins=num_bins, weights=v_weights)
        matrix[:,num_periods+1]=counts
        v_legend[num_periods+1]='Yearly'
        plt.hist(bins[:-1], bins, weights=counts)
        plt.legend(v_legend[1:num_periods+2:])
        #Write line with the limits
        for j in range(len(v_limits)):
            h = plt.axvline(v_limits[j], color='r', linestyle='--')
        #plt.text(0.76, 120000, '1,596 buses out of limits  ', fontsize = 10)
        plt.xlabel(type+' (p.u.)')
        plt.ylabel('Frequency (p.u.)')
        plt.savefig(output_file_full_path_fig, dpi=300)
        plt.show()
        #Save to file
        # Write directly as a CSV file with headers on first line
        with open(output_file_full_path_csv, 'w') as fp:
            fp.write(','.join(v_legend) + '\n')
            np.savetxt(fp, matrix, '%s', ',')
        #Deprecated with dataframes
        #pd_values = pd.DataFrame(matrix,index=bins)
        #pd_values.to_csv(output_file_full_path) 


    def plot_losses(self,v_subs_losses_yearly,v_line_losses_yearly):
        output_file_full_path_fig = self.folder + '/' + 'Losses' + '.png'
        plt.figure
        plt.plot(sorted(v_subs_losses_yearly,reverse=True))
        plt.plot(sorted(v_line_losses_yearly,reverse=True))
        plt.plot(sorted(np.add(v_subs_losses_yearly,v_line_losses_yearly),reverse=True))
        plt.legend(['Substation losses','Line losses','Total losses'])
        plt.xlabel('Hour (h)')
        plt.ylabel('Losses (kWh)')
        plt.savefig(output_file_full_path_fig)
        plt.show()


    def get_graph(self,edges):
        graph=nx.Graph()
        for idx,element in enumerate(edges):
            graph.add_edges_from(element)
        return graph

    def get_locations(self,graph,bus,locations=[],x_locations_levels={},parent=None,level=0,visited_buses=[]):
        #Add to the list of visited buses
        if visited_buses:
            visited_buses.append(bus)
        else:
            visited_buses=[bus]
        #Obtain the buses connected to this one
        connected_buses = list(graph.neighbors(bus))
        #Explore downstream levels
        x_downstream_locations=[]
        for downstream_bus in connected_buses:
            #Remove the terminal from the bus nmae
            downstream_bus=self.remove_terminal(downstream_bus)
            #If the bus was already visited, remove from graph (if activated this would remove loops)
            #if downstream_bus!=parent and downstream_bus in visited_buses and graph.has_edge(bus,downstream_bus) and b_remove_loops:
            #Remove self loops (possible to happen because of terminals in buses)
            if downstream_bus==bus:
                graph.remove_edge(bus,downstream_bus)
            else:
                #Explore downstream the graph (recursive search)
                if downstream_bus!=parent and not downstream_bus in visited_buses:
                    x_loc,locations=self.get_locations(graph,downstream_bus,locations,x_locations_levels,bus,level+1,visited_buses)
                    x_downstream_locations.append(x_loc)
        #For the upper levels, it takes the average of the downstream buses
        if x_downstream_locations:
            loc=(sum(x_downstream_locations)/len(x_downstream_locations),-level);
        else:
            if x_locations_levels:
                #Pick up location from this level or the previous ones                
                #It is neccesary to sort it, to pick in the above for lev loop the x_next_location from the more downstream level
                for lev in sorted(x_locations_levels):                    
                    if lev<=level:
                        x_next_location=x_locations_levels[lev]+1
                #Assign location x, y
                loc=(x_next_location,-level)
            else: 
                #Default position for first bus
                loc=(1,-level)
        #Assign x location of this level
        x_locations_levels[level]=loc[0]
        #update locations
        if locations:
            locations[bus]=loc
        else:
            locations={bus:loc}
        #Return x location of this bus (all locations are provided in locations argument)
        return loc[0],locations               

        


    def plot_graph(self,edges,v_dict_voltage,v_range,v_dict_loading,v_range_loading,dict_buses_element):
        output_file_full_path_fig = self.folder + '/' + 'Network Violations' + '.png'
        #output_file_full_path_fig = folder + '/' + type + '.png'
        #Example
        graph=nx.Graph()
        #graph.add_edges_from([(1,2), (1,3), (1,4), (1,5), (1,2), (2,6), (6,7), (7,1)])
        #discard,locations=self.get_locations(graph,1)
        graph=self.get_graph(edges)
        discard,locations=self.get_locations(graph,'st_mat')
        #Obtain number of violations of each node
        cmap = plt.cm.get_cmap('jet')
        dic_num_violations_v={}
        for node in graph:
            #Truncate list to limits              
            dic_num_violations_v[node]=0
            for idx2,value in enumerate(v_dict_voltage[node]):  
                if value<v_range[0] or value>=v_range[1]:
                    dic_num_violations_v[node]=dic_num_violations_v[node]+1
        #Make colormap
        color_map_v=[]
        max_violations_v=max(dic_num_violations_v.values())
        for node in graph:
            if max_violations_v==0:
                intensity=0
            else:
                intensity=dic_num_violations_v[node]/max_violations_v
            #color_map_v.append(cmap_nodes(intensity))
            color_map_v.append(intensity)
        #Obtain number of violations of each branch
        dic_num_violations_l={}
        for edge in graph.edges():
            #Truncate list to limits              
            dic_num_violations_l[edge]=0
            #bus1to2=self.remove_terminal(edge[0])+'-->'+self.remove_terminal(edge[1])
            #bus2to1=self.remove_terminal(edge[1])+'-->'+self.remove_terminal(edge[0])
            bus1to2=self.remove_terminal(edge[0])+'-->'+self.remove_terminal(edge[1])
            bus2to1=self.remove_terminal(edge[1])+'-->'+self.remove_terminal(edge[0])
            if bus1to2 in dict_buses_element:
                element=dict_buses_element[bus1to2]
            else:
                element=dict_buses_element[bus2to1]
            for idx2,value in enumerate(v_dict_loading[element]):  
                if value<v_range_loading[0] or value>=v_range_loading[1]:
                    dic_num_violations_l[edge]=dic_num_violations_l[edge]+1
        #Make colormap
        color_map_l=[]
        max_violations_l=max(dic_num_violations_l.values())
        for edge in graph.edges():
            if max_violations_l==0:
                intensity=0
            else:
                intensity=dic_num_violations_l[edge]/max_violations_l
            #color_map_v.append(cmap_nodes(intensity))
            color_map_l.append(intensity)
        #Obtain min and max of x locations
        max_x=0
        max_y=0
        for idx,name in enumerate(locations):
            if (max_x<locations[name][0]):
                max_x=locations[name][0]
            if (max_y<-locations[name][1]):
                max_y=-locations[name][1]
        #plt.figure(figsize=(max_x,max_y))
        unitary_size=0.5
        ratio=16/9
        maximum=max(max_x,max_y)*unitary_size
        plt.figure(figsize=(maximum*ratio,maximum))
        nodes = nx.draw_networkx_nodes(graph, pos=locations, node_color=color_map_v, cmap=cmap)
        edges=nx.draw_networkx_edges(graph,pos=locations, edge_color=color_map_l,width=4,edge_cmap=cmap)
        nx.draw_networkx_labels(graph, pos=locations)
        num_ticks_v=5
        ticks_v = np.linspace(0, 1, num_ticks_v) 
        labels_v = np.linspace(0, max_violations_v, num_ticks_v) 
        cbar=plt.colorbar(nodes,ticks=ticks_v) 
        cbar.ax.set_yticklabels(["{:4.2f}".format(i) for i in labels_v]) # add the labels
        cbar.set_label("Voltage violations (h)", fontsize=10, y=0.5, rotation=90)
        cbar.ax.yaxis.set_label_position('left')
        num_ticks_l=5
        ticks_l = np.linspace(0, 1, num_ticks_l) 
        labels_l = np.linspace(0, max_violations_l, num_ticks_l) 
        cbar=plt.colorbar(edges,ticks=ticks_l) 
        cbar.ax.set_yticklabels(["{:4.2f}".format(i) for i in labels_l]) # add the labels
        cbar.set_label("Thermal limit violations (h)", fontsize=10, y=0.5, rotation=90)
        cbar.ax.yaxis.set_label_position('left')
        plt.axis('off')
        wm = plt.get_current_fig_manager()
        wm.window.state('zoomed')
        plt.savefig(output_file_full_path_fig, dpi=300)
        plt.show()



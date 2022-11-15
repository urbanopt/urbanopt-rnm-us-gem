import opendssdirect as dss       
import pandas as pd
#import matplotlib
import matplotlib.pyplot as plt
import numpy as np
import sys as sys
import math
import networkx as nx
import opendss_interface
import seaborn as sns
import plotly.graph_objects as go
from shapely.geometry import LineString
from shapely.geometry import Point
import geopandas as gpd


class Plot_Lib:
    def __init__(self, folder,b_numeric_ids):
        """Initialices the folder variables"""
        self.main_folder = folder
        self.folder=folder+'/Validation'
        self.b_numeric_ids=b_numeric_ids

    def remove_terminal(self,bus):
        """Removes the terminal from the bus name"""
        myopendss_io=opendss_interface.OpenDSS_Interface(self.folder,self.b_numeric_ids)
        bus=myopendss_io.remove_terminal(bus)
        return bus


    def plot_hist(self,subfolder,type,v_value,v_value_period,v_range,num_periods,num_bins,v_months):
        """Plots an histogram"""
        # Path and file name
        output_file_full_path_fig = self.folder + '/' + subfolder + '/Figures/' + type +  ' Histogram (p.u.).png'
        output_file_full_path_csv = self.folder + '/' + subfolder + '/CSV/' + type + ' Histogram (p.u.).csv'
        # New figure
        # plt.figure
        plt.clf()
        # Activate figure grid
        plt.grid(True)
        # Evaluate number of valid periods
        num_valid_periods=0
        for j in v_months:
            #If data in the month
            if not j==[]:
                num_valid_periods=num_valid_periods+1
        # Init variables
        v_legend=["" for _ in range(num_valid_periods+1)]
        matrix=np.empty((num_bins,num_valid_periods+1)) #Matrix for writting to file (index+periods+yearly)
        # Set xlim
        if v_range['display_range']:
            plt.xlim(v_range['display_range'])
        # Incremental index for months with data
        i=0        
        # For each month
        for j in v_months:
            #If data in the month
            if not j==[]:
                # Set the weight variable
                v_weights = np.ones_like(v_value_period[j]) / len(v_value_period[j])
                # Calculate the histogram of each month
                counts, bins = np.histogram(v_value_period[j], range=v_range['display_range'], bins=num_bins, weights=v_weights)
                # Update matrix and legend
                # In subsequent iterations
                matrix[:,i]=counts
                v_legend[i]="M"+str(j+1)
                # Plot the month
                plt.plot(bins[:-1]+(bins[1]-bins[0])*0.5, counts)
                # Increment index if data
                i=i+1
        # Set the weight variable
        v_weights = np.ones_like(v_value) / len(v_value)
        # Calculate the yearly histogram
        counts, bins = np.histogram(v_value, range=v_range['display_range'], bins=num_bins, weights=v_weights)
        # Update matrix and legend
        matrix[:,i]=counts
        v_legend[i]='Yearly'
        # Plot histogram
        plt.hist(bins[:-1], bins, weights=counts)
        # Plot legend
        #plt.legend(v_legend[1:num_periods+2:])
        plt.legend(v_legend)
        # Write line with the limits
        for j in range(len(v_range['limits'])):
            h = plt.axvline(v_range['limits'][j], color='r', linestyle='--')
        # x,y lables
        plt.xlabel(type)
        plt.ylabel('Frequency (p.u.)')
        # Save to file
        plt.savefig(output_file_full_path_fig, dpi=300)
        # Display
        # plt.show()
        # Save data to file
        # Write directly as a CSV file with headers on first line
        with open(output_file_full_path_csv, 'w') as fp:
            fp.write(','.join(v_legend) + '\n')
            np.savetxt(fp, matrix, '%.7f', ',')

    def plot_violin(self,subfolder,type,v_value,v_range):
        """Make a figure with a violin plot"""
        # Path and file name
        output_file_full_path_fig = self.folder + '/' + subfolder + '/' + type +  ' Violin Plot.png'
        # New figure
        # plt.figure
        plt.clf()
        # Write line with the limits
        for j in range(len(v_range['limits'])):
            h = plt.axhline(v_range['limits'][j], color='r', linestyle='--')
        # Plot violtin
        sns.violinplot(y=v_value, cut=0, color='orange')
        # Strip plot (display points)
        sns.stripplot(y=v_value, color='blue')
        # y label
        plt.ylabel(type)
        # y limit
        if v_range['display_range']:
            plt.ylim(v_range['display_range'])
        # Save figure to file
        plt.savefig(output_file_full_path_fig, dpi=300)
        # Display
        # plt.show()

    def plot_violin_two_vars(self,subfolder, type,v_value1,v_value2,v_range):
        """Make a figure with a violin plot of two variables (kW/kVAr)"""
        # Path and file name
        output_file_full_path_fig = self.folder + '/' + subfolder + '/' + type +  ' Violin Plot.png'
        # New figure
        # plt.figure
        plt.clf()
        # Init variables
        v_data=[]
        v_type=[]
        # Write line with the limits
        for j in range(len(v_range['limits'])):
            h = plt.axhline(v_range['limits'][j], color='r', linestyle='--')
        # Extend lists for yearly var1
        l_type=['kW' for _ in v_value1]
        v_data.extend(v_value1)
        v_type.extend(l_type)
        # Extend lists for yearly var2
        l_type=['kVAr' for _ in v_value2]
        v_data.extend(v_value2)
        v_type.extend(l_type)
        # Display violin plot
        sns.violinplot(y=v_data, hue=v_type, cut=0, split=True, palette = {'kW':'blue','kVAr':'orange'})
        # Set y label
        plt.ylabel(type)
        # Set y limit
        if v_range['display_range']:
            plt.ylim(v_range['display_range'])
        # Save figure to file
        plt.savefig(output_file_full_path_fig, dpi=300)
        # Display
        # plt.show()


    def plot_violin_monthly(self,subfolder, type,v_value,v_value_period,v_range,num_periods,v_months):
        """Make a violin plot with the monthly variation"""
        # Path and file name
        output_file_full_path_fig = self.folder + '/' + subfolder + '/' + type +  ' Violin Plot.png'
        # New figure
        # plt.figure
        plt.clf()
        # Init variables
        v_data=[]
        v_month=[]
        v_yearly=[]
        # Write line with the limits
        for j in range(len(v_range['limits'])):
            h = plt.axhline(v_range['limits'][j], color='r', linestyle='--')
        # Incremental index for valid months
        i=0
        # For each month
        for j in v_months:
            # If data in the month
            if not j==[]:
                # Extend lists for monthly
                l_month=["M"+str(j+1) for _ in v_value_period[j]]
                l_yearly=['Monthly' for _ in v_value_period[j]]
                v_data.extend(v_value_period[j])
                v_month.extend(l_month)
                v_yearly.extend(l_yearly)
                # Extend lists for yearly
                l_month=["M"+str(j+1) for _ in v_value]
                l_yearly=['Yearly' for _ in v_value]
                v_data.extend(v_value)
                v_month.extend(l_month)
                v_yearly.extend(l_yearly)
                #Increment auto-index if there is data
                i=i+1
        # Display violin plot
        sns.violinplot(x=v_month, y=v_data, hue=v_yearly, cut=0, split=True)
        # Set y label
        plt.ylabel(type)
        # Set y limit
        if v_range['display_range']:
            plt.ylim(v_range['display_range'])
        # Save figure to file
        plt.savefig(output_file_full_path_fig, dpi=300)
        # Display
        # plt.show()

    def plot_violin_monthly_two_vars(self,subfolder, type,v_value1,v_value1_period,v_value2,v_value2_period,v_range,num_periods,v_months):
        """Make a violin plot for two variables (kW/kVAr) with the monthly variation"""
        # Path and file name
        output_file_full_path_fig = self.folder + '/' + subfolder + '/' + type +  ' Violin Plot.png'
        # New figure
        # plt.figure
        plt.clf()
        # Init variables
        v_data=[]
        v_month=[]
        v_type=[]
        # Incremental index for valid months
        i=0
        for j in v_months:
            #If there is data
            if not j==[]:
                # Extend lists for monthly var1
                l_month=["M"+str(j+1) for _ in v_value1_period[j]]
                l_type=['kW' for _ in v_value1_period[j]]
                v_data.extend(v_value1_period[j])
                v_month.extend(l_month)
                v_type.extend(l_type)
                # Extend lists for monthly var2
                l_month=["M"+str(j+1) for _ in v_value2_period[j]]
                l_type=['kVAr' for _ in v_value2_period[j]]
                v_data.extend(v_value2_period[j])
                v_month.extend(l_month)
                v_type.extend(l_type)
                #Increment auto-index if there is data
                i=i+1
        # Extend lists for yearly var1
        l_month=['Yearly' for _ in v_value1]
        l_type=['kW' for _ in v_value1]
        v_data.extend(v_value1)
        v_month.extend(l_month)
        v_type.extend(l_type)
        # Extend lists for yearly var2
        l_month=['Yearly' for _ in v_value2]
        l_type=['kVAr' for _ in v_value2]
        v_data.extend(v_value2)
        v_month.extend(l_month)
        v_type.extend(l_type)
        # Show violin plot
        sns.violinplot(x=v_month, y=v_data, hue=v_type, cut=0, split=True)
        # Show stripplot (points) (disabled because there are too many points)
        # sns.stripplot(x=v_month, y=v_data, hue=v_type, color="k", alpha=0.8)
        # Set x,y lables
        plt.xlabel('Month')
        plt.ylabel(type)
        # Set y limit
        if v_range['display_range']:
            plt.ylim(v_range['display_range'])
        # Save figure to file
        plt.savefig(output_file_full_path_fig, dpi=300)
        # Display
        # plt.show()        

    def plot_duration_curve(self,subfolder, v1_yearly,v2_yearly,b_losses,v_hours):
        """Make a figure with the duration curve (yearly losses or load)"""
        # New figure
        # plt.figure
        plt.clf()
        # Display variable 1
        plt.plot(v_hours,sorted(v1_yearly,reverse=True))
        # Display variable 1
        plt.plot(v_hours,sorted(v2_yearly,reverse=True))
        # If displaying losses
        if b_losses:
            # Plot the added curve (lines + transformers)
            plt.plot(v_hours,sorted(np.add(v1_yearly,v2_yearly),reverse=True))
            # Set file path + name
            output_file_full_path_fig = self.folder + '/' + subfolder + '/' + 'Losses' + '.png'
            # Set legend
            plt.legend(['Substation losses','Line losses','Total losses'])
            # Set y label
            plt.ylabel('Losses (kWh)')
        else: # If displaying load
            # Set file path + name
            output_file_full_path_fig = self.folder + '/' + subfolder + '/' + 'Load' + '.png'
            # Set legend
            plt.legend(['kW','kVAr'])
            # Set y label
            plt.ylabel('Load')
        # Set x label    
        plt.xlabel('Hour (h)')
        # Save figure to file
        plt.savefig(output_file_full_path_fig)
        # Display
        # plt.show()


    def add_edges(self,graph,edges):
        """Add edges to the graph"""
        # Populate it with the edges
        for idx,element in enumerate(edges):
            graph.add_edges_from([(element[0],element[1])])
        return graph

    def get_locations(self,graph,bus,locations=[],x_location_max_prev=0,parent=None,level=0,visited_buses=[]):
        """Get the locations of the buses in the graph"""
        # Add to the list of visited buses
        if visited_buses:
            visited_buses.append(bus)
        else:
            visited_buses=[bus]
        # Obtain the buses connected to this one
        connected_buses = list(graph.neighbors(bus))
        # Explore downstream levels
        x_downstream_locations=[]
        for downstream_bus in connected_buses:
            # Remove the terminal from the bus name
            downstream_bus=self.remove_terminal(downstream_bus)
            # If the bus was already visited, remove from graph (if activated this would remove loops)
            # if downstream_bus!=parent and downstream_bus in visited_buses and graph.has_edge(bus,downstream_bus) and b_remove_loops:
            # Remove self loops (possible to happen because of terminals in buses)
            if downstream_bus==bus:
                graph.remove_edge(bus,downstream_bus)
            else:
                # Explore downstream the graph (recursive search)
                if downstream_bus!=parent and not downstream_bus in visited_buses:
                    x_loc,locations,x_location_max_prev=self.get_locations(graph,downstream_bus,locations,x_location_max_prev,bus,level+1,visited_buses)
                    x_downstream_locations.append(x_loc)
        # For the upper levels, it takes the average of the downstream buses
        if x_downstream_locations:
            loc=(sum(x_downstream_locations)/len(x_downstream_locations),-level);
        else:
            if x_location_max_prev:
                # Pick up location from this level or the previous ones                
                # It is neccesary to sort it, to pick in the above for lev loop the x_next_location from the more downstream level
                x_next_location=x_location_max_prev+1
                # Assign location x, y
                loc=(x_next_location,-level)
            else: 
                # Default position for first bus
                loc=(1,-level)
        # Assign x location of this level
        if x_location_max_prev<loc[0]:
            x_location_max_prev=loc[0]
        # update locations
        if locations:
            locations[bus]=loc
        else:
            locations={bus:loc}
        # Return x location of this bus (all locations are provided in locations argument)
        return loc[0],locations,x_location_max_prev               


    def get_dict_num_violations_v(self,graph,v_dict_voltage,v_range,v_dict_ids_buses):
        """It obtains number (hours) of voltage violations of each bus"""
        myopendss_io=opendss_interface.OpenDSS_Interface(self.folder,self.b_numeric_ids)
        # Init dict
        dic_num_violations_v={}
        # For each node
        for node in graph:
            # Get dict of violations
            if (self.b_numeric_ids):
                dic_num_violations_v[node]=myopendss_io.get_num_violations(v_dict_voltage[v_dict_ids_buses[node]],v_range,node,None)
            else:
                dic_num_violations_v[node]=myopendss_io.get_num_violations(v_dict_voltage[node],v_range,node,None)
        return dic_num_violations_v


    def get_dict_num_violations_l(self,graph,dict_buses_element,v_dict_loading,v_range_loading,v_dict_ids_buses):
        """It obtains number (hours) of violations of each branch"""
        # Obtain number of violations (hours) of each branch
        myopendss_io=opendss_interface.OpenDSS_Interface(self.folder,self.b_numeric_ids)
        # Init dict
        dic_num_violations_l={}
        # For each granch
        for edge in graph.edges():
            # Obtain name from bus1 to bus2
            if not self.b_numeric_ids:
                bus1to2=self.remove_terminal(edge[0])+'-->'+self.remove_terminal(edge[1])
            else:
                bus1to2=self.remove_terminal(v_dict_ids_buses[edge[0]])+'-->'+self.remove_terminal(v_dict_ids_buses[edge[1]])
            # Obtain name from bus2 to bus1
            if not self.b_numeric_ids:
                bus2to1=self.remove_terminal(edge[1])+'-->'+self.remove_terminal(edge[0])
            else:
                bus2to1=self.remove_terminal(v_dict_ids_buses[edge[1]])+'-->'+self.remove_terminal(v_dict_ids_buses[edge[0]])
            # If bus1 to bus2 is the one that exists in the dictionary
            if bus1to2 in dict_buses_element:
                # Set element name
                element=dict_buses_element[bus1to2]
                # Evaluate number of violations
                dic_num_violations_l[edge]=myopendss_io.get_num_violations(v_dict_loading[element],v_range_loading,element,None)
            elif bus2to1 in dict_buses_element: #If bus2 to bus1 is the one that exists in the dictionary
                # Set element name
                element=dict_buses_element[bus2to1]
                # Evaluate number of violations
                dic_num_violations_l[edge]=myopendss_io.get_num_violations(v_dict_loading[element],v_range_loading,element,None)
            else: # If the element does not exist in the dictionary, set number of violations to zero
                dic_num_violations_l[edge]=0
        return dic_num_violations_l



    def plot_graph(self,subfolder,my_closed_edges,my_open_edges,v_dict_voltage,v_range,v_dict_loading,v_range_loading,dict_buses_element,v_dict_buses_ids,v_dict_ids_buses):
        """Plot a graph with the hierarchical representation of the network"""
        # Path and file name
        output_file_full_path_fig = self.folder + '/' + subfolder + '/' + 'Network Violations' + '.png'
        # New figure
        # plt.figure
        plt.clf()
        # Close the previous fig
        plt.close()
        # Create empty graph
        mygraph=nx.Graph()
        # Commented graph example
        # mygraph.add_edges_from([(1,2), (1,3), (1,4), (1,5), (1,2), (2,6), (6,7), (7,1)])
        # discard,locations=self.get_locations(mygraph,1)
        # Populate the graph with the closed edges
        mygraph=self.add_edges(mygraph,my_closed_edges)
        mygraph_only_closed_edges=mygraph.copy()
        # Populate the graph with the open edges
        mygraph=self.add_edges(mygraph,my_open_edges)
        # Get the locations of the buses
        # WARNING: Locations are extracter from closed edges. This requires that there are no disconnected buses (e.g. two open switches in series)
        if self.b_numeric_ids:
            discard,locations,x_location_max_prev=self.get_locations(mygraph_only_closed_edges,str(0)) #function get_all_buses_ids sets slack bus to str(0)
        else:
            discard,locations,x_location_max_prev=self.get_locations(mygraph_only_closed_edges,'st_mat') #RNM-US specific (the slack bus of the distribution system is always "st_mat")
        # Create colormap
        cmap = plt.cm.get_cmap('jet')
        # Take subset of colormap to avoid dark colors (with overlap with text)
        cmap = cmap.from_list('trunc({n},{a:.3f},{b:.3f})'.format(n=cmap.name, a=0.15, b=0.75),cmap(np.linspace(0.25, 0.75, 120)))
        # Init colormap variable
        color_map_v=[]
        # Get number of voltage valiations
        dic_num_violations_v=self.get_dict_num_violations_v(mygraph,v_dict_voltage,v_range,v_dict_ids_buses)
        # Obtain the maximum number of voltage violations in a bus
        max_violations_v=max(dic_num_violations_v.values())
        # if no violations, use only one color in the colormap
        if max_violations_v==0:
            cmap_v = cmap.from_list('trunc({n},{a:.3f},{b:.3f})'.format(n=cmap.name, a=0, b=0),cmap(np.linspace(0, 0, 2)))
        else:
            cmap_v = cmap
        # Creater a colormap (color_map_v) o colour the buses according to their number of violations
        for node in mygraph:
            # If there are no violations, set all intensities to zero
            if max_violations_v==0:
                intensity=0
            else:
                intensity=dic_num_violations_v[node]/max_violations_v
            # Add the intensity of the bus to the colormap
            color_map_v.append(intensity)
        # Init colormap variables
        color_map_l_closed=[] 
        color_map_l_open=[]
        # Get number of loading valiations
        dic_num_violations_l=self.get_dict_num_violations_l(mygraph,dict_buses_element,v_dict_loading,v_range_loading,v_dict_ids_buses)
        # Obtain the maximum number of loading violations in a branch
        max_violations_l=max(dic_num_violations_l.values())
        # if no violations, use only one color in the colormap
        if max_violations_l==0:
            cmap_l = cmap.from_list('trunc({n},{a:.3f},{b:.3f})'.format(n=cmap.name, a=0, b=0.01),cmap(np.linspace(0, 0.01, 2)))
        else:
            cmap_l = cmap
        # Creater a colormap (color_map_l) o colour the closed branches according to their number of violations
        for edge in mygraph_only_closed_edges.edges():
            # If there are no violations, set all intensities to zero
            if max_violations_l==0:
                intensity=0
            else:
                intensity=dic_num_violations_l[edge]/max_violations_l
            # Add the intensity of the branch to the colormap
            color_map_l_closed.append(intensity)
        # Creater a colormap for the open branches
        for edge in mygraph.edges():
            # Add the intensity of the branch to the colormap
            if not edge in mygraph_only_closed_edges.edges():
                color_map_l_open.append(0) #As it is a different graph, order may be different, but it does not matter because they are all zero
        #Obtain min and max of x locations
        max_x=0
        max_y=0
        for idx,name in enumerate(locations):
            if (max_x<locations[name][0]):
                max_x=locations[name][0]
            if (max_y<-locations[name][1]):
                max_y=-locations[name][1]
        # Define the size of the figure
        unitary_size=0.5
        ratio=16/9
        maximum=max(max_x,max_y)*unitary_size
        if (maximum>40):
            maximum=40
        plt.figure(figsize=(maximum*ratio,maximum))
        # Set transparency parameter
        myalpha=0.6
        # Draw the nodes
        nodes = nx.draw_networkx_nodes(mygraph, pos=locations, node_color=color_map_v, cmap=cmap_v,alpha=myalpha)
        # Draw the closed edges (solid lines)
        edges=nx.draw_networkx_edges(mygraph_only_closed_edges,pos=locations, edge_color=color_map_l_closed,width=4,edge_cmap=cmap_l,alpha=myalpha)
        # Show the buses names
        nx.draw_networkx_labels(mygraph, pos=locations,font_size=8)        
        # Make the ticks, lables, and colorbar
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
        # Draw the open edges (dashed lines)
        edges=nx.draw_networkx_edges(mygraph,edgelist=my_open_edges,pos=locations, edge_color=color_map_l_open,width=4,edge_cmap=cmap_l,style='--',alpha=myalpha)
        # Don't display the axis in the figure
        plt.axis('off')
        # Maximize figure
        wm = plt.get_current_fig_manager()
        backend_name = plt.get_backend()
        # this won't work on mac but should work on windows?
        # macosx does not have a "window" attribute
        if backend_name.lower() != 'macosx':
            wm.window.state('zoomed')

        # Save the figure to file
        plt.savefig(output_file_full_path_fig, dpi=300)
        # Display
        plt.show()

using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

[GlobalClass]
public partial class Graph : Node
{
	
	class Vertex{
		public Variant data;
		public int d = 0;

		public Vertex(Variant data)
		{
			this.data=data;
		}
	}

	List<Vertex> all_vertices = new List<Vertex>();
	Dictionary<Variant, Vertex> vertex_dict = new Dictionary<Variant, Vertex>();
	Dictionary<Vertex,List<Vertex>> all_connections = new Dictionary<Vertex,List<Vertex>>();

	public Graph(){
		
	}

	public void Initialize(Godot.Collections.Array verts, Godot.Collections.Dictionary<Variant,Godot.Collections.Array> edges)
	{
		all_vertices.Clear();
		vertex_dict.Clear();
		all_connections.Clear();

		foreach (Variant val in verts)
		{
			if (vertex_dict.ContainsKey(val))
				continue;
			Vertex v = new Vertex(val);
			all_vertices.Add(v);
			vertex_dict.Add(val, v);
			all_connections[v] = new List<Vertex>();
		}

		foreach (Variant src_val in edges.Keys)
		{
			foreach (Variant dest_val in edges[src_val])
			{
				if (vertex_dict.ContainsKey(src_val) && vertex_dict.ContainsKey(dest_val))
					all_connections[vertex_dict[src_val]].Add(vertex_dict[dest_val]);
			}
		}
	}
	
	enum Properties
	{
		Disconnected,
		Connected,
		HasLoops,
	}

	Properties  check_connected(List<Vertex> verts, bool without_loops)
	{	
		int remaining_visits = verts.Count;
		Dictionary<Vertex, List<Vertex>> shallow_copy = new Dictionary<Vertex, List<Vertex>>(all_connections);
		
		Dictionary<Vertex,bool> visited = [];
		foreach(Vertex v in all_vertices)
			visited[v] = false;
		
		Queue<Vertex> visiting = [];
		visiting.Enqueue(verts[0]);

		while (visiting.Count > 0 && remaining_visits>0)
		{
			Vertex temp = visiting.Dequeue();
			
			visited[temp]=true;
			if (verts.Contains(temp))
				remaining_visits-=1;	
			
			foreach (Vertex new_v in shallow_copy[temp])
			{
				if (without_loops && shallow_copy[new_v].Contains(temp))
				{
					List<Vertex> shallow_list_copy = new List<Vertex>(shallow_copy[new_v]);
					shallow_list_copy.Remove(temp);
					shallow_copy[new_v]=shallow_list_copy;
				}

				if (!visited[new_v])
					visiting.Enqueue(new_v);
				else if (without_loops)
					return Properties.HasLoops;
			}
		}
		if (remaining_visits==0)
			return Properties.Connected;
		else
			return Properties.Disconnected;
	}

	public void build_spanning_tree_between(Godot.Collections.Array verts)
	{
		List<Vertex> verts_list = [];
		foreach (Variant val in verts)
		{
			if (vertex_dict.ContainsKey(val))
			{
				verts_list.Add(vertex_dict[val]);
				GD.Print(val);
			}
		}
		GD.Print("----");
		if (verts_list.Count>1)
			spanning_tree(verts_list);
	}

	void spanning_tree(List<Vertex> verts)
	{
		Random rng = new Random();
		Vertex[] shuffled_vertices_arr = new List<Vertex>(all_connections.Keys).ToArray();
		
		rng.Shuffle<Vertex>(shuffled_vertices_arr);

		Queue<Vertex> shuffled_vertices = new Queue<Vertex>(shuffled_vertices_arr);
		
		while (shuffled_vertices.Count > 0)
		{
			Vertex curr_vertex = shuffled_vertices.Dequeue();
			
			//if (verts.Contains(curr_vertex) && curr_vertex.d==1)
			//	continue;
			
			Vertex[] shuffled_connections_arr = all_connections[curr_vertex].ToArray();

			rng.Shuffle<Vertex>(shuffled_connections_arr);

			Queue<Vertex> shuffled_connections = new Queue<Vertex>(shuffled_connections_arr);
			
			while (shuffled_connections.Count > 0)
			{
				Vertex temp_connection = shuffled_connections.Dequeue();
				all_connections[curr_vertex].Remove(temp_connection);

				if (check_connected(verts, false) == Properties.Disconnected)
				{
					all_connections[curr_vertex].Add(temp_connection);
				}
			}
		}
	}

	public Godot.Collections.Array get_remaining_connections()
	{
		var result_set = new HashSet<Tuple<Vertex,Vertex>>();
		foreach (Vertex v in all_connections.Keys)
		{
			foreach (Vertex other_v in all_connections[v])
			{
				var alt_opt = new Tuple<Vertex,Vertex>(other_v, v);
				if (!result_set.Contains(alt_opt))
					result_set.Add(new Tuple<Vertex,Vertex>(v,other_v));
			}
		}
		
		List<Variant> result_list = new List<Variant>(result_set.Count);
		foreach(Tuple<Vertex,Vertex> verts in result_set)
		{
			var pair = new Godot.Collections.Array([verts.Item1.data,verts.Item2.data]);
			
			result_list.Add((Variant) pair);
			foreach (Variant v in pair)
			{
				GD.Print(v);
			}
		}
		return new Godot.Collections.Array(result_list);
	}
}

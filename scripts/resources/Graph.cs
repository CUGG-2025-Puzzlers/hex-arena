using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

[GlobalClass]
public partial class Graph : Node
{

	private class Vertex(Variant data)
	{
		public Variant data = data;
	}

	private List<Vertex> all_vertices = new List<Vertex>();
	private Dictionary<Variant, Vertex> vertex_dict = new Dictionary<Variant, Vertex>();
	private Dictionary<Vertex, List<Vertex>> all_connections = new Dictionary<Vertex, List<Vertex>>();

	public Graph(){}

	public void InitializeFromHexCenters(Godot.Collections.Array centers)
	{
		Clear();
		foreach (Vector2I center in centers)
		{
			List<Vertex> hex_points = [];
			int x = center.X;
			int y = center.Y;

			int parity = Mathf.PosMod(y,2);
			int x1 = Mathf.RoundToInt(x-1.5*y+0.5*parity);
			int y1 = Mathf.RoundToInt(2*x+parity);
			
			Vector2I new_center = new Vector2I(x1,y1);
			
			foreach(Vector2I dir in new List<Vector2I>([Vector2I.Right,Vector2I.One, Vector2I.Down, Vector2I.Left,-Vector2I.One,Vector2I.Up]))
			{
				hex_points.Add(new Vertex(new_center+dir));
			}
			for(int i =0; i<hex_points.Count; i++)
			{
				Vertex v = hex_points[i];
				if (!all_vertices.Contains(v))
				{
					all_vertices.Add(v);
					vertex_dict[v.data]=v;
					all_connections[v]=[];
				}
				Vertex v1 = hex_points[(i+1)%hex_points.Count];
				if (!all_connections[v].Contains(v1))
					all_connections[v].Add(v1);
				v1 = hex_points[(i-1+hex_points.Count)%hex_points.Count];
				if (!all_connections[v].Contains(v1))
					all_connections[v].Add(v1);
			}
		}
	}


	public void Initialize(Godot.Collections.Array verts, Godot.Collections.Dictionary<Variant, Godot.Collections.Array> edges)
	{
		Clear();

		foreach (Variant val in verts)
		{
			if (vertex_dict.ContainsKey(val))
				continue;
			Vertex v = new Vertex(val);
			all_vertices.Add(v);
			vertex_dict.Add(val, v);
			all_connections[v] = [];
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

	private enum Properties
	{
		Disconnected,
		Connected,
		HasLoops,
	}

	private Properties Check_connected(List<Vertex> verts, bool without_loops)
	{
		int remaining_visits = verts.Count;
		Dictionary<Vertex, List<Vertex>> shallow_copy = new Dictionary<Vertex, List<Vertex>>(all_connections);

		Dictionary<Vertex, bool> visited = [];
		foreach (Vertex v in all_vertices)
			visited[v] = false;

		Queue<Vertex> visiting = [];
		visiting.Enqueue(verts[0]);

		while (visiting.Count > 0 && remaining_visits > 0)
		{
			Vertex temp = visiting.Dequeue();

			visited[temp] = true;
			if (verts.Contains(temp))
				remaining_visits -= 1;

			foreach (Vertex new_v in shallow_copy[temp])
			{
				if (without_loops && shallow_copy[new_v].Contains(temp))
				{
					List<Vertex> shallow_list_copy = new List<Vertex>(shallow_copy[new_v]);
					shallow_list_copy.Remove(temp);
					shallow_copy[new_v] = shallow_list_copy;
				}

				if (!visited[new_v])
					visiting.Enqueue(new_v);
				else if (without_loops)
					return Properties.HasLoops;
			}
		}
		if (remaining_visits == 0)
			return Properties.Connected;
		else
			return Properties.Disconnected;
	}

	public void BuildSpanningTreeBetweenRandom(int num)
	{
		Vertex[] shuffled_vertices_arr = all_connections.Keys.ToArray();
		Random rng = new Random();
		rng.Shuffle<Vertex>(shuffled_vertices_arr);
		List<Vertex> shuffled_vertices = new List<Vertex>();
		for (int i =0; i<Mathf.Min(num,shuffled_vertices_arr.Length); i++)
			shuffled_vertices.Add(shuffled_vertices_arr[i]);
		
		Spanning_tree(shuffled_vertices);
	}

	public void BuildSpanningTreeBetween(Godot.Collections.Array verts)
	{
		List<Vertex> verts_list = [];
		foreach (Variant val in verts)
		{
			if (vertex_dict.ContainsKey(val))
			{
				verts_list.Add(vertex_dict[val]);
			}
		}
		if (verts_list.Count > 1)
			Spanning_tree(verts_list);
	}

	private void Spanning_tree(List<Vertex> verts)
	{
		Random rng = new Random();
		Vertex[] shuffled_vertices_arr = new List<Vertex>(all_connections.Keys).ToArray();
		rng.Shuffle<Vertex>(shuffled_vertices_arr);
		Queue<Vertex> shuffled_vertices = new Queue<Vertex>(shuffled_vertices_arr);

		while (shuffled_vertices.Count > 0)
		{
			Vertex curr_vertex = shuffled_vertices.Dequeue();

			Vertex[] shuffled_connections_arr = all_connections[curr_vertex].ToArray();
			rng.Shuffle<Vertex>(shuffled_connections_arr);
			Queue<Vertex> shuffled_connections = new Queue<Vertex>(shuffled_connections_arr);

			while (shuffled_connections.Count > 0)
			{
				Vertex temp_connection = shuffled_connections.Dequeue();
				all_connections[curr_vertex].Remove(temp_connection);

				if (Check_connected(verts, false) == Properties.Disconnected)
				{
					all_connections[curr_vertex].Add(temp_connection);
				}
			}
		}
	}

	public Godot.Collections.Array GetRemainingConnections()
	{
		var result_set = new HashSet<Tuple<Vertex, Vertex>>();
		foreach (Vertex v in all_connections.Keys)
		{
			foreach (Vertex other_v in all_connections[v])
			{
				var alt_opt = new Tuple<Vertex, Vertex>(other_v, v);
				if (!result_set.Contains(alt_opt))
					result_set.Add(new Tuple<Vertex, Vertex>(v, other_v));
			}
		}

		List<Variant> result_list = new List<Variant>(result_set.Count);
		foreach (Tuple<Vertex, Vertex> verts in result_set)
		{
			var pair = new Godot.Collections.Array([verts.Item1.data, verts.Item2.data]);
			result_list.Add((Variant)pair);
		}
		return new Godot.Collections.Array(result_list);
	}

	private void Clear()
	{
		all_vertices = new List<Vertex>();
		vertex_dict = new Dictionary<Variant, Vertex>();
		all_connections = new Dictionary<Vertex, List<Vertex>>();
	}
}

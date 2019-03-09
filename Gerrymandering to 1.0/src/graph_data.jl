"""
    get_nxgraph(filename)

Read a networkx graph gpickle (filename) file created in python and
return a ::PyObject networkx graph
"""
function get_nxgraph(filename::String)
    graph = nx[:read_gpickle](filename)
    return graph
end


"""
    convert_graph(graph)

Convert LightGraphs(graph) to Networkx(graph_nx).
"""
function convert_graph(graph::SimpleGraph)
    ajm = convert(Array, adjacency_matrix(graph))
    graph_nx = nx[:Graph](ajm)
    return graph_nx
end


"""
    convert_graph(graph_nx)

Convert Networkx(graph_nx) to LightGraphs(graph)
"""
function convert_graph(graph_nx::PyObject)
    matrix_nx = nx[:to_numpy_matrix](graph_nx)
    graph = Graph(matrix_nx)
    return graph
end


"""
    get_demographic(graph_nx)

Get the demographic data from (graph_nx) and
return instance of (DemographicData)
"""
function get_demographic(graph_nx::PyObject)
    pop = collect(values(sort(Dict{Integer, Int64}(
        nx[:get_node_attributes](graph_nx, "pop")))))
    pos = collect(values(sort(Dict{Integer, Tuple{Float64,Float64}}(
        nx[:get_node_attributes](graph_nx, "pos")))))
    dem = collect(values(sort(Dict{Integer, Int64}(
        nx[:get_node_attributes](graph_nx, "dem")))))
    rep = collect(values(sort(Dict{Integer, Int64}(
        nx[:get_node_attributes](graph_nx, "rep")))))
    area = collect(values(sort(Dict{Integer, Int64}(
        nx[:get_node_attributes](graph_nx, "rep")))))

    demographic = DemographicData(pos, pop, dem, rep, area)
    return demographic
end


"""
    initialize_districts()

Create the intial partition of the graph using python's metis package
"""
function initialize_districts()
    println("Creating initial districts")
    targets = convert(Array{Any,1},[1/num_parts for i in 1:num_parts])

    edgecuts, parts = metis[:part_graph](
        graph_nx, num_parts, contig=true, tpwgts=targets, ufactor = 1)

    for i in 1:length(parts)
        parts[i] += 1
    end

    pop = zeros(Int64, num_parts)
    dem = zeros(Int64, num_parts)
    rep = zeros(Int64, num_parts)
    for i in vertices(graph)
        pop[parts[i]] += demographic.pop[i]
        dem[parts[i]] += demographic.dem[i]
        rep[parts[i]] += demographic.rep[i]
    end
    districts = DistrictData(parts, dem, rep, pop)
    return districts
end


"""
    initialize_data(pickle_filename, shapef_filename)

read nxgraph, convert to lightgraph, connect all of the discontinuos
parts and updates nxgraph with new edges.
"""
function initialize_data(pickle_filename::String, shapef_filename::String)
    println("Initializing data")
    shapefile = gpd[:read_file](shapef_filename)
    shapefile[:insert](1, "districts", 1)

    graph_nx = get_nxgraph(pickle_filename)
    graph = convert_graph(graph_nx)

    demographic = get_demographic(graph_nx)
    connect_graph!(graph,  demographic.pos)

    graph_nx = convert_graph(graph)

    return graph, graph_nx, shapefile, demographic
end


struct DemographicData
    pos::Array{Tuple{Float64, Float64}}
    pop::Array{Int64}
    dem::Array{Int64}
    rep::Array{Int64}
    area::Array{Float64}
end


mutable struct DistrictData
    dis::Array{Int64}
    dem::Array{Int64}
    rep::Array{Int64}
    pop::Array{Int64}
end
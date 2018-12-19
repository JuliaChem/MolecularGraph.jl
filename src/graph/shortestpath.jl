#
# This file is a part of graphmol.jl
# Licensed under the MIT License http://opensource.org/licenses/MIT
#

export
    shortestpath,
    reachablenodes,
    pathlength,
    backtrack


function shortestpath(graph::AbstractUGraph, u, v)
    if u == v
        return
    end
    queue = [u]
    pred = Dict{Int,Union{Int,Nothing}}(u => nothing)
    while !isempty(queue)
        i = popfirst!(queue)
        for nbr in neighborkeys(graph, i)
            if nbr == v
                # v found
                path = [v]
                p = i
                while p !== nothing
                    pushfirst!(path, p)
                    p = pred[p]
                end
                return path
            elseif !(nbr in keys(pred))
                # New nodes
                pred[nbr] = i
                push!(queue, nbr)
            end
        end
    end
    # return nothing if not reachable
end


function reachablenodes(graph::AbstractDGraph, source)
    pred = shortestpath(graph, source)
    delete!(pred, source)
    return keys(pred)
end


function pathlength(graph::AbstractDGraph, source)
    res = Dict{Int,Int}()
    pred = shortestpath(graph, source)
    for p in keys(pred)
        path = backtrack(pred, source, p)
        res[p] = length(path) - 1
    end
    return res
end


function shortestpath(graph::AbstractDGraph, source)
    queue = [source]
    pred = Dict{Int,Union{Int,Nothing}}(source => nothing)
    while !isempty(queue)
        i = popfirst!(queue)
        for succ in succkeys(graph, i)
            if !(succ in keys(pred))
                # New nodes
                pred[succ] = i
                push!(queue, succ)
            end
        end
    end
    return pred
end


function backtrack(pred::Dict{Int,Union{Int,Nothing}}, source, target)
    path = []
    p = target
    while p !== nothing
        pushfirst!(path, p)
        if p == source
            break
        end
        p = pred[p]
    end
    return path
end
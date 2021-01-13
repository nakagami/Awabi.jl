################################################################################
# MIT License
#
# Copyright (c) 2021 Hajime Nakagami
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
################################################################################
using DataStructures

mutable struct Node
    entry::Union{DicEntry, Nothing}
    pos::Int32
    epos::Int32
    index::Int32
    left_id::Int32
    right_id::Int32
    cost::Int32
    min_cost::Int32
    back_pos::Int32
    back_index::Int32
    skip::Bool
end

function new_bos()::Node
    Node(
        nothing,    # entry
        0,          # pos
        1,          # epos
        0,          # index
        -1,         # left_id
        0,          # right_id,
        0,          # cost
        0,          # min_cost
        -1,         # back_pos
        -1,         # back_index
        false       # skip
    )
end

function new_eos(pos::Int32)::Node
    Node(
        nothing,    # entry
        pos,        # pos
        pos+1,      # epos
        0,          # index
        0,          # left_id
        -1,         # right_id,
        0,          # cost
        0x7FFFFFFF, # min_cost
        -1,         # back_pos
        -1,         # back_index
        false       # skip
    )
end

function new_node(e::DicEntry)
    Node(
        e,          # entry
        0,          # pos
        0,          # epos
        e.posid,    # index
        e.lc_attr,  # left_id
        e.rc_attr,  # right_id,
        e.wcost,    # cost
        0x7FFFFFFF, # min_cost
        -1,         # back_pos
        -1,         # back_index
        e.skip      # skip
    )
end

function is_bos(node::Node)::Bool
    node.entry == nothing && node.pos == 0
end

function is_eos(node::Node)::Bool
    node.entry == nothing && node.pos != 0
end

function node_len(node::Node)::Int32
    if node.entry == nothing
        Int32(1)
    else
        Int32(length(node.entry.original))
    end
end

mutable struct Lattice
    snodes::Vector{Vector{Node}}
    enodes::Vector{Vector{Node}}
    p::Int32
end

function new_lattice(size::Int64)
    snodes::Vector{Vector{Node}} = []
    enodes::Vector{Vector{Node}} = []

    push!(enodes,[])
    for _ in 1:(size + 2)
        push!(snodes, [])
        push!(enodes, [])
    end
    bos::Node = new_bos()
    push!(snodes[1], bos)
    push!(enodes[2], bos)

    Lattice(snodes, enodes, 1)
end

function add!(lattice::Lattice, node::Node, matrix::Matrix)
    min_cost = node.min_cost
    best_node = lattice.enodes[lattice.p+1][1]

    for enode in lattice.enodes[lattice.p+1]
        if enode.skip
            for enode2 in lattice.enodes[enode.pos+1]
                cost = enode2.min_cost + get_trans_cost(matrix, UInt16(enode2.right_id), UInt16(node.left_id))
                if cost < min_cost
                    min_cost = cost
                    best_node = enode
                end
            end
        else
            cost = enode.min_cost + get_trans_cost(matrix, UInt16(enode.right_id), UInt16(node.left_id))
            if cost < min_cost
                min_cost = cost
                best_node = enode
            end
        end
    end

    node.min_cost = min_cost + node.cost
    node.back_index = best_node.index
    node.back_pos = best_node.pos
    node.pos = lattice.p
    node.epos = lattice.p + node_len(node)
    node.index = length(lattice.snodes[lattice.p+1])
    push!(lattice.snodes[node.pos+1], node)
    push!(lattice.enodes[node.epos+1], node)
end

function forward(lattice::Lattice)::Int64
    old_p = lattice.p
    lattice.p += 1
    while length(lattice.enodes[lattice.p+1]) == 0
        lattice.p += 1
    end
    lattice.p - old_p
end

function end!(lattice::Lattice, matrix::Matrix)
    add!(lattice, new_eos(lattice.p), matrix)
    lattice.snodes = lattice.snodes[1:lattice.p+1]
    lattice.enodes = lattice.enodes[1:lattice.p+2]
end

function backward(lattice::Lattice)::Vector{Node}
    @assert is_eos(lattice.snodes[length(lattice.snodes)][1])

    shortest_path::Vector{Node} = []
    pos = length(lattice.snodes) -1
    index = 0
    while pos >= 0
       node = lattice.snodes[pos+1][index+1]
       index = node.back_index
       pos = node.back_pos
       push!(shortest_path, node)
    end
    reverse(shortest_path)
end

struct BackwardPath
    cost_from_bos::Int32
    cost_from_eos::Int32
    back_path::Vector{Node}
end

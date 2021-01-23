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


struct Tokenizer
    # system dictionary
    sys_dic::MecabDic
    # user dictional
    user_dic::Union{MecabDic, Nothing}

    # for unknown chars
    char_propery::CharProperty
    unk_dic::MecabDic

    #trans cost matrix
    matrix::Matrix

    function Tokenizer(mecabrc_map::Dict{String, String})
        sys_dic = get_mecabdic(get_dic_path(mecabrc_map, "sys.dic"))
        if haskey(mecabrc_map, "userdic")
            user_dic = get_mecabdic(mecabrc_map["userdic"])
        else
            user_dic = nothing
        end
        char_property = get_char_propery(get_dic_path(mecabrc_map, "char.bin"))
        unk_dic = get_mecabdic(get_dic_path(mecabrc_map, "unk.dic"))
        matrix = get_matrix(get_dic_path(mecabrc_map, "matrix.bin"))
        new(sys_dic, user_dic, char_property, unk_dic, matrix)
    end

    function Tokenizer(mecabrc_path::AbstractString)
        Tokenizer(get_mecabrc_map(mecabrc_path))
    end

    function Tokenizer()
        Tokenizer(find_mecabrc())
    end
end


function build_lattice(tokenizer::Tokenizer, sentence::String)::Lattice
    s = Vector{UInt8}(sentence)
    lattice = new_lattice(length(s))
    pos = 0
    while pos < length(s)
        matched = false

        # user_dic
        if tokenizer.user_dic != nothing
            user_entries = lookup(user_dic, s[(pos+1):length(s)])
            if length(user_entries) > 0
                for e in user_entries
                    add!(lattice, new_node(e), tokenizer.matrix)
                end
                matched = true
            end
        end

        # sys_dic
        sys_entries = lookup(tokenizer.sys_dic, s[(pos+1):length(s)])
        if length(sys_entries) > 0
            for e in sys_entries
                add!(lattice, new_node(e), tokenizer.matrix)
            end
            matched = true
        end

        # unknown
        unk_entries, invoke = lookup_unknowns(tokenizer.unk_dic, s[pos+1:length(s)], tokenizer.char_propery)
        if invoke || !matched
            for e in unk_entries
                add!(lattice, new_node(e), matrix, tokenizer.matrix)
            end
        end

        pos += forward(lattice)
    end
    end!(lattice, tokenizer.matrix)

    # dump_nodes_list("snodes", lattice.snodes)
    # dump_nodes_list("enodes", lattice.enodes)

    lattice
end

function tokenize(tokenizer::Tokenizer, s::AbstractString)::Vector{Tuple{String, String}}
    entries::Vector{Tuple{String, String}} = []

    lattice = build_lattice(tokenizer, s)
    nodes = backward(lattice)
    @assert is_bos(nodes[1])
    @assert is_eos(nodes[length(nodes)])
    for i in 2:(length(nodes) -1)
        push!(entries, (String(nodes[i].original), String(nodes[i].feature)))
    end

    entries
end

function tokenize_n_best(tokenizer::Tokenizer, s::AbstractString, n::Int)::Vector{Vector{Tuple{String, String}}}
    morphemes_list = []

    lattice = build_lattice(tokenizer, s)
    for nodes in backward_astar(lattice, n, tokenizer.matrix)
        morphemes = []
        for node in nodes[2:length(nodes)-2]
            push!(morphemes, (String(node.original), String(node.feature)))
        end
        push!(morphemes_list, morphemes)
    end

    morphemes_list
end

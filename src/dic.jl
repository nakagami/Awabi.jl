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
using Mmap

const MAX_GROUPING_SIZE = 24

struct DicEntry
    original::String
    lc_attr::UInt16
    rc_attr::UInt16
    posid::UInt16
    wcost::Int16
    feature::String
    skip::Bool
end

#------------------------------------------------------------------------------

struct CharProperty
    mmap::Vector{UInt32}
    category_names:: Vector{String}
end

function char_to_ucs2(ch::Char)::UInt16
    UInt16(UInt32(ch) & 0xFFFF)
end

function get_char_propery(path::AbstractString)::CharProperty
    category_names = []
    f = open(path)
    num_categories = read(f, UInt32)
    for i in 1:num_categories
        raw_data = zeros(UInt8, 32)
        readbytes!(f, raw_data, 32)
        push!(category_names, String(raw_data[1:findfirst(x -> x==0, raw_data)-1]))
    end
    mmap = Mmap.mmap(f, Vector{UInt32}, 0xFFFF)
    CharProperty(mmap, category_names)
end

#------------------------------------------------------------------------------

struct MeCabDic
    mmap
    dic_size::UInt32
    lsize::UInt32
    rsize::UInt32
    da_offset::UInt32
    token_offset::UInt32
    feature_offset::UInt32
end

#------------------------------------------------------------------------------

struct Matrix
    mmap::Vector{Int16}
    lsize::UInt32
    rsize::UInt32
end

function get_matrix(path::AbstractString)::Matrix
    f = open(path)
    lsize = UInt32(read(f, UInt16))
    rsize = UInt32(read(f, UInt16))
    mmap = Mmap.mmap(f, Vector{Int16}, lsize * rsize)
    Matrix(mmap, lsize, rsize)
end

function get_trans_cost(m::Matrix, id1::UInt16, id2::UInt16)::Int16
    m.mmap[UInt32(id2) * m.lsize + UInt32(id1) + 1]
end

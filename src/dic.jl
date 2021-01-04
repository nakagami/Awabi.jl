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

struct CharInfo
    default_type::UInt32
    type::UInt32
    char_count::UInt32
    group::UInt32
    invoke::UInt32
end

function utf8_to_ucs2(s::Vector{UInt8}, index::Int64)::Tuple{UInt16, Int64}
    # utf8 to ucs2(16bit) code and it's array size
    ln::Int64 = 0

    if (s[index] & 0b10000000) == 0b00000000
        ln = 1
    elseif (s[index] & 0b11100000) == 0b11000000
        ln = 2
    elseif (s[index] & 0b11110000) == 0b11100000
        ln = 3
    elseif (s[index] & 0b11111000) == 0b11110000
        ln = 4
    end

    if ln == 1
        ch32 = UInt32(s[index+0])
    elseif ln == 2
        ch32 = UInt32(s[index+0] & 0x1F) << 6
        ch32 |= s[index+1] & 0x3F
    elseif ln == 3
        ch32 = UInt32(s[index+0] & 0x0F) << 12
        ch32 |= UInt32(s[index+1] & 0x3F) << 6
        ch32 |= s[index+2] & 0x3F
    elseif ln == 4
        ch32 = UInt32(s[index+0] & 0x07) << 18
        ch32 |= UInt32(s[index+1] & 0x3F) << 12
        ch32 |= UInt32(s[index+2] & 0x3F) << 6
        ch32 |= s[index+3] & 0x03F
    end

    # ucs4 to ucs2
    if ch32 < 0x10000
        ch16 = UInt16(ch32)
    else
        ch16 = UInt16((((ch32-0x10000) // 0x400 + 0xD800) << 8) + ((ch32-0x10000) % 0x400 + 0xDC00))
    end
    (ch16, ln)
end

function get_char_propery(path::AbstractString)::CharProperty
    category_names = []
    f = open(path)
    num_categories = read(f, UInt32)
    for _ in 1:num_categories
        raw_data = zeros(UInt8, 32)
        readbytes!(f, raw_data, 32)
        push!(category_names, String(raw_data[1:findfirst(x -> x==0, raw_data)-1]))
    end
    mmap = Mmap.mmap(f, Vector{UInt32}, 0xFFFF)
    CharProperty(mmap, category_names)
end

function get_char_info(cp::CharProperty, code_point::UInt16)::CharInfo
    v = cp.mmap[code_point+1]
    CharInfo(
        (v >> 18) & 0b11111111,
        v & 0b111111111111111111,
        (v >> 26) & 0b1111,
        (v >> 30) & 0b1,
        (v >> 31) & 0b1
    )
end

function get_group_length(cp::CharProperty, s::Vector{UInt8}, default_type::UInt32)::Int64
    i = 1
    char_count = 0
    while i <= length(s)
        ch16, ln = utf8_to_ucs2(s, i)
        char_info = get_char_info(cp, ch16)
        if ((1 << default_type) & char_info.type) != 0
            i += ln
            char_count += 1
            if char_count > MAX_GROUPING_SIZE
                return -1
            end
        else
            break
        end
    end
    i - 1
end

function get_count_length(cp::CharProperty, s::Vector{UInt8}, default_type::UInt32, count::Int64)::Int64
    i = 1
    j = 1
    while j <= count
        if i > length(s)
            return -1
        end
        ch16, ln = utf8_to_ucs2(s, i)
        char_info = get_char_info(cp, ch16)
        if ((1 << default_type) & char_info.type) == 0
            return -1
        end
        i += ln
        j += 1
    end
    i - 1
end

function get_unknown_lengths(cp::CharProperty, s::Vector{UInt8})::Tuple{UInt32, Vector{Int64}, Bool}
    ln_list::Vector{Int64} = []
    ch16, first_ln = utf8_to_ucs2(s, 1)
    char_info = get_char_info(cp, ch16)
    if group != 0
        ln = self.get_group_length(s, default_type)
        if ln > 0
            push!(ln_list, ln)
        end
    end
    if count != 0
        n = 1
        while n <= count
            ln = get_count_length(cp, char_info.default_type, n)
            if ln < 0
                break
            end
            push!(ln_list, ln)
            n += 1
        end
    end
    if length(ln_list) == 0
        push!(ln_list, fist_ln)
    end
    (char_info.default_type, ln_list, char_info.invoke == 1)
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

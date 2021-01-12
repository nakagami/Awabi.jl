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
    original::Vector{UInt8}
    lc_attr::UInt16
    rc_attr::UInt16
    posid::UInt16
    wcost::Int16
    feature::Vector{UInt8}
    skip::Bool
end

#------------------------------------------------------------------------------

struct CharProperty
    mmap::Vector{UInt32}
    category_names:: Vector{Vector{UInt8}}
end

struct CharInfo
    default_type::UInt32
    type::UInt32
    count::UInt32
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
    else
        throw("invalid utf8 string array: $(s)")
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
        push!(category_names, view(raw_data, 1:findfirst(x -> x==0, raw_data)-1))
    end
    mmap = Mmap.mmap(f, Vector{UInt32}, 0xFFFF)
    close(f)
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

function get_unknown_lengths(cp::CharProperty, s::Vector{UInt8})::Tuple{UInt32, Vector{UInt32}, Bool}
    ln_list::Vector{UInt32} = []
    ch16, first_ln = utf8_to_ucs2(s, 1)
    char_info = get_char_info(cp, ch16)
    if char_info.group != 0
        ln = get_group_length(cp, s, char_info.default_type)
        if ln > 0
            push!(ln_list, ln)
        end
    end
    if char_info.count != 0
        n = 1
        while n <= char_info.count
            ln = get_count_length(cp, s, char_info.default_type, n)
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

struct MecabDic
    mmap::Vector{UInt8}
    dic_size::UInt32
    lsize::UInt32
    rsize::UInt32
    da_offset::UInt32
    token_offset::UInt32
    feature_offset::UInt32
end

function get_mecabdic(path::AbstractString)::MecabDic
    f = open(path)
    dic_size = read(f, UInt32) ^ 0xef718f77
    version = read(f, UInt32)
    dictype = read(f, UInt32)
    lexsize = read(f, UInt32)
    lsize = read(f, UInt32)
    rsize = read(f, UInt32)
    dsize = read(f, UInt32)
    tsize = read(f, UInt32)
    fsize = read(f, UInt32)
    read(f, UInt32)     # 0:dummy
    raw_data = zeros(UInt8, 32)
    readbytes!(f, raw_data, 32)
    charset = String(raw_data[1:findfirst(x -> x==0, raw_data)-1])
    da_offset = 1
    token_offset = 1 + dsize
    feature_offset = token_offset + tsize
    mmap = Mmap.mmap(f, Vector{UInt8}, filesize(path)-72)
    close(f)
    MecabDic(
        mmap, dic_size, lsize, rsize,
        da_offset, token_offset, feature_offset
    )
end

function base_check(dic::MecabDic, idx::UInt32)::Tuple{Int32, UInt32}
    i = dic.da_offset + idx * 8
    (reinterpret(Int32, view(dic.mmap, i:i+3))[1], reinterpret(UInt32, view(dic.mmap, i+4:i+7))[1])
end

function exact_match_search(dic::MecabDic, s::Vector{UInt8})::Int32
    v::Int32 = -1
    b, _ = base_check(dic, UInt32(0))
    for item in s
        p = UInt32(b + Int32(item) + 1)
        base, check = base_check(dic, p)
        if b == Int32(check)
            b = base
        else
            return v
        end
    end

    p = UInt32(b)
    n, check = base_check(dic, p)
    if b == Int32(check) && n < 0
        v = Int32(-n-1)
    end

    v
end

function common_prefix_search(dic::MecabDic, s::Vector{UInt8})::Vector{Tuple{Int32, Int64}}
    results::Vector{Tuple{Int32, Int64}} = []
    b, _ = base_check(dic, UInt32(0))
    for i in 1:length(s)
        item = s[i]
        p = UInt32(b)
        n, check = base_check(dic, p)
        if b == Int32(check) && n < 0
            push!(results, (-n-1, Int64(i)-1))
        end
        p = UInt32(b + Int32(item) + 1)
        base, check = base_check(dic, p)
        if b == Int32(check)
            b = base
        else
            return results
        end
    end
    p = UInt(b)
    n, check = base_check(dic, p)
    if b == Int32(check) && n < 0
        push!((-n-1, length(s)))
    end

    results
end

function get_entries_by_index(dic::MecabDic, idx::UInt32, count::UInt32, s::Vector{UInt8}, skip::Bool)::Vector{DicEntry}
    results::Vector{DicEntry} = []
    for i in 1:count
        offset = dic.token_offset + (idx + i-1) * 16
        lc_attr = reinterpret(UInt16, view(dic.mmap, offset:offset+1))[1]
        rc_attr = reinterpret(UInt16, view(dic.mmap, offset+2:offset+3))[1]
        posid = reinterpret(UInt16, view(dic.mmap, offset+4:offset+5))[1]
        wcost = reinterpret(Int16, view(dic.mmap, offset+6:offset+7))[1]
        feature_len = reinterpret(UInt32, view(dic.mmap, offset+8:offset+11))[1]
        feature_start = offset + feature_len
        x = feature_start
        while dic.mmap[x] != 0
            x = x+1
        end
        feature = view(dic.mmap, offset+feature_len:x-1)
        push!(results, DicEntry(s, lc_attr, rc_attr, posid, wcost, feature, skip))
    end

    results
end

function get_entries(dic::MecabDic, result::UInt32, s::Vector{UInt8}, skip::Bool)::Vector{DicEntry}
    idx = result >> 8
    count = result & 0xFF
    get_entries_by_index(dic, idx, count, s, skip)
end

function lookup(dic::MecabDic, s::Vector{UInt8})::Vector{DicEntry}
    results::Vector{DicEntry} = []
    for (result, len) in common_prefix_search(dic, s)
        idx = UInt32(result >> 8)
        count = UInt32(result & 0xFF)
        results = vcat(results, get_entries_by_index(dic, idx, count, s, false))
    end

    results
end

function lookup_unknowns(dic::MecabDic, s::Vector{UInt8}, cp::CharProperty)::Tuple{Vector{DicEntry}, Bool}
    default_type, ln_vec, invoke = get_unknown_lengths(cp, s)
    category_name = cp.category_names[default_type]
    result = exact_match_search(dic, category_name)
    results::Vector{DicEntry} = []
    for i in ln_vec
        new_results = get_entries(dic, UInt32(result), s[1:i], category_name == b"SPACE")
        results = vcat(results, new_results)
    end

    (results, invoke)
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
    close(f)
    Matrix(mmap, lsize, rsize)
end

function get_trans_cost(m::Matrix, id1::UInt16, id2::UInt16)::Int16
    m.mmap[UInt32(id2) * m.lsize + UInt32(id1) + 1]
end

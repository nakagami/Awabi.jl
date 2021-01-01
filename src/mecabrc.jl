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

function find_mecabrc()::Union{String, Nothing}
    for s = ["/usr/local/etc/mecabrc", "/etc/mecabrc"]
        if isfile(s)
            return s
        end
    end
    Nothing
end

function get_mecabrc_map(rc_path)::Dict{String, String}
    mecabrc_map = Dict()
    
    open(rc_path, "r") do f
        for s = readlines(f)
            m = match(r"^(\S+)\s*=\s*(\S+)", s)
            if m != nothing
                mecabrc_map[m[1]] = m[2]
            end
        end
    end

    mecabrc_map
end

function get_mecabrc_map()
    get_mecabrc_map(find_mecabrc())
end

# Awabi.jl

`Awabi.jl` is a morphological analyzer using mecab dictionary, written in Julia.

## Requirements

MeCab https://taku910.github.io/mecab/ and related dictionary is required.

Debian/Ubuntu
```
$ sudo apt install mecab mecab-ipadic-utf8
```

Mac OS X (homebrew)
```
$ brew install mecab
$ brew install mecab-ipadic
```

## How to use

```
julia> using Awabi

julia> tokenize(Tokenizer(), "すもももももももものうち")
7-element Array{Tuple{String,String},1}:
 ("すもも", "名詞,一般,*,*,*,*,すもも,スモモ,スモモ")
 ("も", "助詞,係助詞,*,*,*,*,も,モ,モ")
 ("もも", "名詞,一般,*,*,*,*,もも,モモ,モモ")
 ("も", "助詞,係助詞,*,*,*,*,も,モ,モ")
 ("もも", "名詞,一般,*,*,*,*,もも,モモ,モモ")
 ("の", "助詞,連体化,*,*,*,*,の,ノ,ノ")
 ("うち", "名詞,非自立,副詞可能,*,*,*,うち,ウチ,ウチ")

julia>
```

## See also

- awabi https://github.com/nakagami/awabi

using Test, Awabi

@testset "mecabrc" begin
    @test Awabi.find_mecabrc() == "/etc/mecabrc"
    mecabrc_map = Awabi.get_mecabrc_map(Awabi.find_mecabrc())
    @test mecabrc_map["dicdir"] == "/var/lib/mecab/dic/debian"
    @test Awabi.get_dic_path(mecabrc_map, "sys.dic") == "/var/lib/mecab/dic/debian/sys.dic"
end


@testset "dic" begin
    # Matrix
    m = Awabi.get_matrix(
        Awabi.get_dic_path(Awabi.get_mecabrc_map(Awabi.find_mecabrc()), "matrix.bin")
    )
    @test Awabi.get_trans_cost(m, UInt16(555), UInt16(1283)) == 340
    @test Awabi.get_trans_cost(m, UInt16(10), UInt16(1293)) == -1376

    # CharInfo
    cp = Awabi.get_char_propery(
        Awabi.get_dic_path(Awabi.get_mecabrc_map(Awabi.find_mecabrc()), "char.bin")
    )
    @test cp.category_names == [
        b"DEFAULT", b"SPACE", b"KANJI", b"SYMBOL", b"NUMERIC", b"ALPHA",
        b"HIRAGANA", b"KATAKANA", b"KANJINUMERIC", b"GREEK", b"CYRILLIC"
    ]
    @test Awabi.get_char_info(cp, UInt16(0)) == Awabi.CharInfo(0, 1, 0, 1, 0)         # DEFAULT
    @test Awabi.get_char_info(cp, UInt16(0x20)) == Awabi.CharInfo(1, 2, 0, 1, 0)      # SPACE
    @test Awabi.get_char_info(cp, UInt16(0x09)) == Awabi.CharInfo(1, 2, 0, 1, 0)      # SPACE
    @test Awabi.get_char_info(cp, UInt16(0x6f22)) == Awabi.CharInfo(2, 4, 2, 0, 0)    # KANJI 漢
    @test Awabi.get_char_info(cp, UInt16(0x3007)) == Awabi.CharInfo(3, 264, 0, 1, 1)  # SYMBOL
    @test Awabi.get_char_info(cp, UInt16(0x31)) == Awabi.CharInfo(4, 16, 0, 1, 1)     # NUMERIC 1
    @test Awabi.get_char_info(cp, UInt16(0x3042)) == Awabi.CharInfo(6, 64, 2, 1, 0)   # HIRAGANA あ
    @test Awabi.get_char_info(cp, UInt16(0x4e00)) == Awabi.CharInfo(8, 260, 0, 1, 1)  # KANJINUMERIC 一

    # lookup
    sys_dic = Awabi.get_mecabdic(
        Awabi.get_dic_path(Awabi.get_mecabrc_map(Awabi.find_mecabrc()), "sys.dic")
    )
    s = Vector{UInt8}("すもももももももものうち")
    @test length(Awabi.common_prefix_search(sys_dic, s)) == 3
    @test length(Awabi.lookup(sys_dic, s)) == 9
    s = Vector{UInt8}("もももももも")
    @test length(Awabi.common_prefix_search(sys_dic, s)) == 2
    @test length(Awabi.lookup(sys_dic, s)) == 4

    # lookup_unknowns
    unk_dic = Awabi.get_mecabdic(
        Awabi.get_dic_path(Awabi.get_mecabrc_map(Awabi.find_mecabrc()), "unk.dic")
    )
    @test Awabi.exact_match_search(unk_dic, Vector{UInt8}("SPACE")) == Int32(9729)
    entries, invoke = Awabi.lookup_unknowns(unk_dic, Vector{UInt8}("１９６７年"), cp)
    @test entries[1].original == b"１９６７"
end

@testset "tokenize" begin
    results = [
        [
            ("すもも", "名詞,一般,*,*,*,*,すもも,スモモ,スモモ"),
            ("も", "助詞,係助詞,*,*,*,*,も,モ,モ"),
            ("もも", "名詞,一般,*,*,*,*,もも,モモ,モモ"),
            ("も", "助詞,係助詞,*,*,*,*,も,モ,モ"),
            ("もも", "名詞,一般,*,*,*,*,もも,モモ,モモ"),
            ("の", "助詞,連体化,*,*,*,*,の,ノ,ノ"),
            ("うち", "名詞,非自立,副詞可能,*,*,*,うち,ウチ,ウチ"),
        ],
        [
            ("すもも", "名詞,一般,*,*,*,*,すもも,スモモ,スモモ"),
            ("も", "助詞,係助詞,*,*,*,*,も,モ,モ"),
            ("もも", "名詞,一般,*,*,*,*,もも,モモ,モモ"),
            ("もも", "名詞,一般,*,*,*,*,もも,モモ,モモ"),
            ("も", "助詞,係助詞,*,*,*,*,も,モ,モ"),
            ("の", "助詞,連体化,*,*,*,*,の,ノ,ノ"),
            ("うち", "名詞,非自立,副詞可能,*,*,*,うち,ウチ,ウチ"),
        ],
        [
            ("すもも", "名詞,一般,*,*,*,*,すもも,スモモ,スモモ"),
            ("もも", "名詞,一般,*,*,*,*,もも,モモ,モモ"),
            ("も", "助詞,係助詞,*,*,*,*,も,モ,モ"),
            ("もも", "名詞,一般,*,*,*,*,もも,モモ,モモ"),
            ("も", "助詞,係助詞,*,*,*,*,も,モ,モ"),
            ("の", "助詞,連体化,*,*,*,*,の,ノ,ノ"),
            ("うち", "名詞,非自立,副詞可能,*,*,*,うち,ウチ,ウチ"),
        ],
    ]

    tokenizer = Tokenizer()
    @test tokenize(tokenizer, "すもももももももものうち") == results[1]
    @test tokenize_n_best(tokenizer, "すもももももももものうち", 3) == results
end

@testset "tokenize_unk" begin
    result = [
            ("アイス", "名詞,一般,*,*,*,*,アイス,アイス,アイス"),
    ]
    tokenizer = Tokenizer()
    @test tokenize(tokenizer, "アイス") == result
end

@testset "tokenize_userdic" begin
    result = [
            ("ユーザー辞書", "名詞,一般,*,*,*,*,ユーザー辞書,ユーザージショ,ユーザージショ"),
            ("は", "助詞,係助詞,*,*,*,*,は,ハ,ワ"),
            ("固有名詞", "名詞,一般,*,*,*,*,固有名詞,コユウメイシ,コユーメイシ"),
            ("です", "助動詞,*,*,*,特殊・デス,基本形,です,デス,デス"),
    ]
    tokenizer = Tokenizer()
    @test tokenize(tokenizer, "ユーザー辞書は固有名詞です") == result
end

using Test, Awabi

@testset "mecabrc" begin
    @test Awabi.find_mecabrc() == "/etc/mecabrc"
    mecabrc_map = Awabi.get_mecabrc_map()
    @test mecabrc_map["dicdir"] == "/var/lib/mecab/dic/debian"
    @test Awabi.get_dic_path(mecabrc_map, "sys.dic") == "/var/lib/mecab/dic/debian/sys.dic"
end


@testset "dic" begin
    # Matrix
    m = Awabi.get_matrix(
        Awabi.get_dic_path(Awabi.get_mecabrc_map(), "matrix.bin")
    )
    @test Awabi.get_trans_cost(m, UInt16(555), UInt16(1283)) == 340
    @test Awabi.get_trans_cost(m, UInt16(10), UInt16(1293)) == -1376
end

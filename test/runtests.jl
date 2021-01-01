using Test, Awabi

@testset "mecabrc" begin
    @test Awabi.find_mecabrc() == "/etc/mecabrc"
    mecabrc_map = Awabi.get_mecabrc_map()
    @test mecabrc_map["dicdir"] == "/var/lib/mecab/dic/debian"
    @test Awabi.get_dic_path(mecabrc_map, "sys.dic") == "/var/lib/mecab/dic/debian/sys.dic"
end


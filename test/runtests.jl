using Test, Awabi

@testset "mecabrc" begin
    @test Awabi.find_mecabrc() == "/etc/mecabrc"
    @test Awabi.get_mecabrc_map()["dicdir"] == "/var/lib/mecab/dic/debian"
end


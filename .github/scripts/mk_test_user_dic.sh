#!/bin/sh
TEST_DIR=/tmp

USERDIC_SRC=$TEST_DIR/user_dic.csv
USERDIC=$TEST_DIR/user.dic
DICDIR=/var/lib/mecab/dic/debian
DIC_SRC=/usr/share/mecab/dic/ipadic
CMD_IDX="/usr/lib/mecab/mecab-dict-index"

echo -e "ユーザー辞書,,,6058,名詞,一般,*,*,*,*,ユーザー辞書,ユーザージショ,ユーザージショ" > $USERDIC_SRC
$CMD_IDX -d $DIC_SRC -u $USERDIC -f utf-8 -t utf-8 $USERDIC_SRC

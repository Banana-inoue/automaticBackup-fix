#!/bin/bash
##########################################
# 実行用(Cronにはこのシェルスクリプトを指定する)#
##########################################

# DBバックアップ
./dbbackup.sh

# ファイルバックアップ
./filebackup.sh
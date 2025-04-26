#!/bin/bash

## 通知を送信するメールアドレス
EMAIL=""

## バックアップサーバーの接続設定
# バックアップサーバーのユーザー名
REMOTE_USER=""
# バックアップサーバーのホスト名またはIP
REMOTE_HOST="remote_host"
# バックアップサーバーの保存先ディレクトリ
REMOTE_DIR="/backup/hoge"

## WordPressインストールディレクトリ
WORDPRESS_DIR="/var/www/html"

##バックアップ関係
# バックアップを保存するディレクトリ
BACKUP_DIR="/home/userland/test"
# 日付を付けたバックアップファイル名
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/wordpress_backup_$TIMESTAMP.tar.gz"

# バックアップ開始ログ
LOG_FILE="$BACKUP_DIR/backup_log_$TIMESTAMP.log"

echo "ファイルバックアップ処理開始" >> "$LOG_FILE"

# バックアップディレクトリが存在しない場合に作成
if [ ! -d "$BACKUP_DIR" ]; then
  echo "バックアップディレクトリが存在しないため、作成します: $BACKUP_DIR" >> "$LOG_FILE"
  mkdir -p "$BACKUP_DIR"
fi

# ファイルのバックアップを作成 (gzipで圧縮)
echo "ファイルのバックアップを開始します: $WORDPRESS_DIR" >> "$LOG_FILE"
tar -czf "$BACKUP_FILE" -C "$WORDPRESS_DIR" wordpress >> "$LOG_FILE" 2>> "$LOG_FILE"

# バックアップ成功確認
if [ $? -ne 0 ]; then
  echo "ファイルバックアップが失敗しました。" >> "$LOG_FILE"
  {
    echo "To: $EMAIL"
    echo "Subject: ファイルバックアップが失敗しました。"
    echo
    echo "下記のログを確認してください"
    echo "----------------------------"
    echo | cat "$LOG_FILE"
} | msmtp --file=/home/userland/.msmtprc "$EMAIL"

  exit 1
fi

# scpでリモートサーバーへ転送
scp "$BACKUP_FILE" "$REMOTE_USER"@"$REMOTE_HOST":"$REMOTE_DIR" >> "$LOG_FILE"
if [ $? -ne 0 ]; then
  echo "バックアップファイルの送信に失敗しました" >> "$LOG_FILE"
    {
    echo "To: $EMAIL"
    echo "Subject: バックアップファイルの送信に失敗しました。"
    echo
    echo "下記のログを確認してください"
    echo "----------------------------"
    echo | cat "$LOG_FILE"
} | msmtp --file=/home/userland/.msmtprc "$EMAIL"

  exit 1
fi

# バックアップファイルを削除する
rm "$WORDPRESS_FILE"

echo "ファイルのバックアップが成功しました: $WORDPRESS_FILE" >> "$LOG_FILE"
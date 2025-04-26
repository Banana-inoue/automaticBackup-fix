#!/bin/bash

#TODO:各コマンドをフルパスに変更する(さくらインターネットの縛り)

# 通知を受信するメールアドレス
EMAIL=""

## DB設定
# DB認証ファイル
DB_CONF="/home/userland/test/db.conf"
DB_NAME="wordpress"

# バックアップを保存するディレクトリ
BACKUP_DIR="/home/userland/test"

## バックアップサーバーの接続設定
# バックアップサーバーのユーザー名
REMOTE_USER=""
# バックアップサーバーのホスト名またはIP
REMOTE_HOST="remote_host"
# バックアップサーバーの保存先ディレクトリ
REMOTE_DIR="/backup/hoge"

## バックアップファイル、ログファイル設定
# 日付
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
# 日付を付けたバックアップファイルを作成
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_backup_$TIMESTAMP.sql.gz"
# 日付を付けたログファイルを作成
LOG_FILE="$BACKUP_DIR/backup_log_$TIMESTAMP.log"


# バックアップ開始ログ
echo "バックアップ処理開始" >> "$LOG_FILE"

# バックアップディレクトリが存在しない場合に作成
if [ ! -d "$BACKUP_DIR" ]; then
  echo "バックアップディレクトリが存在しない為、作成します : $BACKUP_DIR" >> "$LOG_FILE"
  mkdir -p "$BACKUP_DIR"
fi

# データベースのバックアップを実施し、圧縮する
# 失敗した場合、ログに出力し、メールで通知する
# mysqldump --defaults-extra-file="$DB_CONF" --single-transaction -A 2>> "$LOG_FILE" | gzip > "$BACKUP_FILE"
mysqldump --defaults-extra-file="$DB_CONF" --single-transaction -B "$DB_NAME" 2>> "$LOG_FILE" | gzip > "$BACKUP_FILE"
if [ $? -ne 0 ]; then
  echo "ダンプ処理が失敗しました" >> "$LOG_FILE"
  rm "$BACKUP_FILE"
  {
    echo "To: $EMAIL"
    echo "Subject: ダンプ処理が失敗しました"
    echo
    echo "下記のログを確認してください"
    echo "----------------------------"
    echo | cat  "$LOG_FILE"
} | msmtp --file=/home/userland/.msmtprc "$EMAIL"
  exit 1
fi

echo "ダンプ処理が成功しました : $BACKUP_FILE" >> "$LOG_FILE"

# scpでリモートサーバーへ転送
scp "$BACKUP_FILE" "$REMOTE_USER"@"$REMOTE_HOST":"$REMOTE_DIR" >> "$LOG_FILE"
if [ $? -ne 0 ]; then
  echo "ダンプファイルの送信に失敗しました" >> "$LOG_FILE"
  {
    echo "To: $EMAIL"
    echo "Subject: ダンプファイルの送信に失敗しました"
    echo
    echo "下記のログを確認してください"
    echo "----------------------------"
    echo | cat "$LOG_FILE"
} | msmtp --file=/home/userland/.msmtprc "$EMAIL"
  exit 1
fi
echo "ダンプファイルの送信が完了しました $REMOTE_HOST:$REMOTE_DIR" >> "$LOG_FILE"

# DBバックアップファイルを削除する
# rm "$BACKUP_FILE"

echo "DBバックアップが完了しました" >> "$LOG_FILE"
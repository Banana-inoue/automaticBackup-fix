#!/bin/bash

#TODO:各コマンドをフルパスに変更する(さくらインターネットの縛り)
#TODO:ログファイルの日本語表示可能か確認する
#TODO:mailコマンドが入っているか確認する(無理ならsmtp、gmailAPI)

# 通知を送信するメールアドレス
EMAIL="hogehoge@banana.co.jp"  

## DB設定
# DB認証ファイル
DB_CONF="/etc/db.conf"

# バックアップを保存するディレクトリ
BACKUP_DIR="/path/to/backup" 

## バックアップサーバーの接続設定
# バックアップサーバーのユーザー名
REMOTE_USER=""
# バックアップサーバーのホスト名またはIP
REMOTE_HOST="remote_host"
# バックアップサーバーの保存先ディレクトリ
REMOTE_DIR="/remote/backup/path"

## バックアップファイル、ログファイル設定
# 日付
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
# 日付を付けたバックアップファイルを作成
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_backup_$TIMESTAMP.sql"
# 日付を付けたログファイルを作成
LOG_FILE="$BACKUP_DIR/backup_log_$TIMESTAMP.log"
ERROR_LOG_FILE="$BACKUP_DIR/backup_error_$TIMESTAMP.log"


# バックアップ開始ログ
echo "バックアップ処理開始" >> "$LOG_FILE"

# バックアップディレクトリが存在しない場合に作成
if [ ! -d "$BACKUP_DIR" ]; then
  echo "バックアップディレクトリが存在しない為、作成します : $BACKUP_DIR" >> "$LOG_FILE"
  mkdir -p "$BACKUP_DIR"
fi

# データベースのバックアップを取得し、エラーログに出力
# 失敗した場合、メールで通知する
# mysqldump -u $DB_USER -p$DB_PASSWORD $DB_NAME > "$BACKUP_FILE" 2>> "$ERROR_LOG_FILE"
mysqldump --defaults-extra-file="$DB_CONF" --single-transaction -A > "$BACKUP_FILE" 2>> "$ERROR_LOG_FILE"
if [ $? -ne 0 ]; then
  echo "バックアップが失敗しました ログを確認してください: $ERROR_LOG_FILE" >> "$LOG_FILE"
  mail -s "バックアップが失敗しました" "$EMAIL" < "$ERROR_LOG_FILE"
  exit 1
fi

echo "バックアップが成功しました : $BACKUP_FILE" >> "$LOG_FILE"

# scpでリモートサーバーへ転送
scp $BACKUP_FILE $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR >> "$LOG_FILE"
if [ $? -ne 0 ]; then
  echo "バックアップファイルの送信に失敗しました　ログを確認してください: $ERROR_LOG_FILE" >> "$LOG_FILE"
  mail -s "バックアップファイルの送信に失敗しました" "$EMAIL" < "$ERROR_LOG_FILE"
  exit 1
fi

echo "バックアップファイルの送信が完了しました $REMOTE_HOST:$REMOTE_DIR" >> "$LOG_FILE"
echo "バックアップが完了しました" >> "$LOG_FILE"

# 成功通知をメールにて送信
mail -s "バックアップが完了しました" "$EMAIL" < "$LOG_FILE"
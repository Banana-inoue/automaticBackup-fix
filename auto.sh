#!/bin/bash

#TODO:パスワードの管理を別ファイルにて行う
#TODO:DBバックアップに失敗した場合、メールにて通知する
#TODO:バックアップサーバーに送信が失敗した場合、メールにて通知する
#TODO:ログファイルの日本語表示可能か確認する

## DB設定

# MySQLユーザー名
DB_USER="" 
# MySQLパスワード
DB_PASSWORD=""
# バックアップするデータベース名
DB_NAME=""  
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
echo "バックアップ開始" >> "$LOG_FILE"

# バックアップディレクトリが存在しない場合に作成
if [ ! -d "$BACKUP_DIR" ]; then
  echo "バックアップディレクトが存在しない為、作成します : $BACKUP_DIR" >> "$LOG_FILE"
  mkdir -p "$BACKUP_DIR"
fi

# データベースのバックアップを取得し、エラーログに出力
mysqldump -u $DB_USER -p$DB_PASSWORD $DB_NAME > "$BACKUP_FILE" 2>> "$ERROR_LOG_FILE"
if [ $? -ne 0 ]; then
  echo "バックアップが失敗しました ログをチェックしてください: $ERROR_LOG_FILE" >> "$LOG_FILE"
  exit 1
fi

echo "バックアップが成功しました : $BACKUP_FILE" >> "$LOG_FILE"

# scpでリモートサーバーへ転送
scp $BACKUP_FILE $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR >> "$LOG_FILE"
if [ $? -ne 0 ]; then
  echo "バックアップファイルの送信が失敗しました　ログを確認してください: $ERROR_LOG_FILE" >> "$LOG_FILE"
  exit 1
fi

echo "バックアップファイルの送信が完了しました $REMOTE_HOST:$REMOTE_DIR" >> "$LOG_FILE"
echo "バックアップが完了しました" >> "$LOG_FILE"
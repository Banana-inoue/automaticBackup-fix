#!/bin/bash

## 通知を送信するメールアドレス
EMAIL=".com"

## バックアップサーバーの接続設定
# バックアップサーバーのユーザー名
REMOTE_USER=""
# バックアップサーバーのホスト名またはIP
REMOTE_HOST="remote_host"
# バックアップサーバーの保存先ディレクトリ
REMOTE_DIR="/backup/hoge"


## WordPressのインストールディレクトリ
WORDPRESS_DIR="/public_html"

##バックアップ関係
# バックアップを保存するディレクトリ
BACKUP_DIR="/backup/"
# 日付を付けたバックアップファイル名
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
WORDPRESS_BACKUP_FILE="$BACKUP_DIR/wordpress_files_backup_$TIMESTAMP.tar.gz"

# バックアップ開始ログ
LOG_FILE="$BACKUP_DIR/backup_log_$TIMESTAMP.log"
ERROR_LOG_FILE="$BACKUP_DIR/backup_error_$TIMESTAMP.log"

echo "WordPressバックアップ処理開始" >> "$LOG_FILE"

# バックアップディレクトリが存在しない場合に作成
if [ ! -d "$BACKUP_DIR" ]; then
  echo "バックアップディレクトリが存在しないため、作成します: $BACKUP_DIR" >> "$LOG_FILE"
  mkdir -p "$BACKUP_DIR"
fi

# WordPressファイルのバックアップを作成 (gzipで圧縮)
echo "WordPressファイルのバックアップを開始します: $WORDPRESS_DIR" >> "$LOG_FILE"
tar -czf "$WORDPRESS_BACKUP_FILE" -C "$WORDPRESS_DIR" . >> "$LOG_FILE" 2>> "$ERROR_LOG_FILE"

# バックアップ成功確認
if [ $? -ne 0 ]; then
  echo "ファイルバックアップが失敗しました。エラーログを確認してください: $ERROR_LOG_FILE" >> "$LOG_FILE"
  mail -s "WordPressファイルバックアップが失敗しました" "$EMAIL" < "$ERROR_LOG_FILE"
  exit 1
fi

# scpでリモートサーバーへ転送
scp $WORDPRESS_BACKUP_FILE $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR >> "$LOG_FILE"
if [ $? -ne 0 ]; then
  echo "バックアップファイルの送信に失敗しました　ログを確認してください: $ERROR_LOG_FILE" >> "$LOG_FILE"
  mail -s "バックアップファイルの送信に失敗しました" "$EMAIL" < "$ERROR_LOG_FILE"
  exit 1
fi

echo "WordPressファイルのバックアップが成功しました: $WORDPRESS_BACKUP_FILE" >> "$LOG_FILE"

# 成功通知をメールで送信
mail -s "WordPressファイルバックアップが完了しました" "$EMAIL" < "$LOG_FILE"

echo "バックアップ完了" >> "$LOG_FILE"

# TODO:最も古いバックファイルを削除する処理を記述
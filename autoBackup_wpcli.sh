#!/bin/bash

#TODO:各コマンドをフルパスに変更する(さくらインターネットの縛り)
#TODO:ログファイルの日本語表示可能か確認する
#TODO:mailコマンドが入っているか確認する(無理ならsmtp、gmailAPI)

# 通知を受信するメールアドレス
EMAIL="sample@jp"

# WordPressパス
WP_PATH="/home/ユーザー名/www"

# バックアップを保存するディレクトリ
BACKUP_DIR="/backup/hoge" 

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
DB_DUMP="$BACKUP_DIR/backup_$TIMESTAMP.sql.gz"
SYSTEM_BACKUP_FILE="$BACKUP_DIR/www_$TIMESTAMP.tar.gz"

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

################# DBバックアップ ###################

# データベースのバックアップを実施し、圧縮する
# 失敗した場合、エラーログに出力し、メールで通知する
/usr/local/bin/wp db export - --path="$WP_PATH" 2>> "$ERROR_LOG_FILE" | gzip > "$DB_DUMP"

# エラーチェック
if [ $? -ne 0 ]; then
  echo "バックアップが失敗しました。ログを確認してください: $ERROR_LOG_FILE" >> "$LOG_FILE"
  mail -s "WordPressバックアップ失敗のお知らせ" "$EMAIL" < "$ERROR_LOG_FILE"
  exit 1
else
  echo "DBバックアップ成功: $DB_DUMP" >> "$LOG_FILE"
fi

#################################################



############# WordPressバックアップ ###############

# ファイルのバックアップを作成 (gzipで圧縮)
echo "ファイルのバックアップを開始します: $WP_PATH" >> "$LOG_FILE"
tar -czf "$SYSTEM_BACKUP_FILE" -C "$WP_PATH" . >> "$LOG_FILE" 2>> "$ERROR_LOG_FILE"

# ファイルバックアップ成功確認
if [ $? -ne 0 ]; then
  echo "ファイルバックアップが失敗しました。エラーログを確認してください: $ERROR_LOG_FILE" >> "$LOG_FILE"
  mail -s "ファイルバックアップが失敗しました" "$EMAIL" < "$ERROR_LOG_FILE"
  exit 1
  else
  echo "ファイルバックアップ成功: $SYSTEM_BACKUP_FILE" >> "$LOG_FILE"
fi

#################################################


# scpでリモートサーバーへ転送
scp $DB_DUMP $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR >> "$LOG_FILE"
if [ $? -ne 0 ]; then
  echo "ダンプファイルの送信に失敗しました　ログを確認してください: $ERROR_LOG_FILE" >> "$LOG_FILE"
  mail -s "ダンプファイルの送信に失敗しました" "$EMAIL" < "$ERROR_LOG_FILE"
  exit 1
fi
echo "ダンプファイルの送信が完了しました $REMOTE_HOST:$REMOTE_DIR" >> "$LOG_FILE"

# DBバックアップファイルを削除する
rm $DB_DUMP


scp $SYSTEM_BACKUP_FILE $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR >> "$LOG_FILE"
if [ $? -ne 0 ]; then
  echo "バックアップファイルの送信に失敗しました　ログを確認してください: $ERROR_LOG_FILE" >> "$LOG_FILE"
  mail -s "バックアップファイルの送信に失敗しました" "$EMAIL" < "$ERROR_LOG_FILE"
  exit 1
fi

rm $$SYSTEM_BACKUP_FILE

echo "フルバックアップが完了しました" >> "$LOG_FILE"

# 成功通知をメールにて送信
mail -s "フルバックアップが完了しました" "$EMAIL" < "$LOG_FILE"

#!/bin/bash

#TODO:各コマンドをフルパスに変更する(さくらインターネットの縛り)

# 通知を受信するメールアドレス
EMAIL="ryo.inoue@bananadream.co.jp"

# バックアップを保存するディレクトリ
BACKUP_DIR="/home/userland/test"

# 日付
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
# 日付を付けたログファイルを作成
LOG_FILE="$BACKUP_DIR/backup_log_$TIMESTAMP.log"


## DB関係############################################################
DB_CONF="/home/userland/test/db.conf"
DB_NAME="wordpress"
DB_BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_db_backup_$TIMESTAMP.sql.gz"
#####################################################################


## WordPress関係######################################################
WORDPRESS_DIR="/var/www/html"
WORDPRESS_BACKUP_FILE="$BACKUP_DIR/wordpress_backup_$TIMESTAMP.tar.gz"
#####################################################################

## バックアップサーバーの接続設定
# バックアップサーバーのユーザー名
REMOTE_USER=""
# バックアップサーバーのホスト名またはIP
REMOTE_HOST="remote_host"
# バックアップサーバーの保存先ディレクトリ
REMOTE_DIR="/backup/hoge"


# バックアップ開始ログ
echo "バックアップ処理開始" >> "$LOG_FILE"

# バックアップディレクトリが存在しない場合に作成
if [ ! -d "$BACKUP_DIR" ]; then
  echo "バックアップディレクトリが存在しない為、作成します : $BACKUP_DIR" >> "$LOG_FILE"
  mkdir -p "$BACKUP_DIR"
fi


# データベースのバックアップを実施し、圧縮する
# 失敗した場合、ログに出力し、メールで通知する
# mysqldump --defaults-extra-file="$DB_CONF" --single-transaction -A 2>> "$LOG_FILE" | gzip > "$DB_BACKUP_FILE"
mysqldump --defaults-extra-file="$DB_CONF" --single-transaction -B "$DB_NAME" 2>> "$LOG_FILE" | gzip > "$DB_BACKUP_FILE"
if [ $? -ne 0 ]; then
  echo "ダンプ処理が失敗しました" >> "$LOG_FILE"
  rm "$DB_BACKUP_FILE"
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

echo "ダンプ処理が成功しました : $DB_BACKUP_FILE" >> "$LOG_FILE"


echo "ファイルバックアップ処理開始" >> "$LOG_FILE"

# ファイルのバックアップを作成 (gzipで圧縮)
echo "ファイルのバックアップを開始します: $WORDPRESS_DIR" >> "$LOG_FILE"
tar -czf "$WORDPRESS_BACKUP_FILE" -C "$WORDPRESS_DIR" wordpress >> "$LOG_FILE" 2>> "$LOG_FILE"

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

echo "ファイルバックアップが完了しました : $WORDPRESS_BACKUP_FILE" >> "$LOG_FILE"

# リモートサーバーへ転送(DB)
scp "$DB_BACKUP_FILE" "$REMOTE_USER"@"$REMOTE_HOST":"$REMOTE_DIR" >> "$LOG_FILE"
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


# リモートサーバーへ転送(WordPress)
scp "$WORDPRESS_BACKUP_FILE" "$REMOTE_USER"@"$REMOTE_HOST":"$REMOTE_DIR" >> "$LOG_FILE"
if [ $? -ne 0 ]; then
  echo "WordPressバックアップファイルの送信に失敗しました" >> "$LOG_FILE"
    {
    echo "To: $EMAIL"
    echo "Subject: WordPressバックアップファイルの送信に失敗しました。"
    echo
    echo "下記のログを確認してください"
    echo "----------------------------"
    echo | cat "$LOG_FILE"
} | msmtp --file=/home/userland/.msmtprc "$EMAIL"

  exit 1
fi

echo "WordPressのバックアップファイルの送信が完了しました $REMOTE_HOST:$REMOTE_DIR" >> "$LOG_FILE"

# バックアップファイル削除
# rm $DB_BACKUP_FILE
# rm $WORDPRESS_BACKUP_FILE

# 完了メール通知
echo "バックアップ処理が完了しました" >> "$LOG_FILE"
    {
    echo "To: $EMAIL"
    echo "Subject: バックアップ処理が完了しました。"
    echo
    echo "下記のログを確認してください"
    echo "----------------------------"
    echo | cat "$LOG_FILE"
} | msmtp --file=/home/userland/.msmtprc "$EMAIL"

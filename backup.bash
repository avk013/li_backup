#!/bin/bash

# --- Настройки ---
BACKUP_DIR="/opt/datas" #!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
FINAL_ARCHIVE_NAME="backup_$(date +%Y-%m-%d).7z"
TAR_ARCHIVE_NAME="temp_backup.tar.gz"
EXCLUDE_FILE="./exclude.txt"
ARCHIVE_PASSWORD="pass"
RECIPIENT_EMAIL="email@mailserver"
EMAIL_SUBJECT="Резервная копия от $(date +%Y-%m-%d)"
EMAIL_BODY="Здравствуйте!
Прикрепляю к письму резервную копию Tralalal.
Архив защищен паролем.
С уважением,
Ваш скрипт бэкапа."

# Файл для хранения размера последнего бэкапа
LAST_SIZE_FILE="/tmp/backup_size.txt"

# --- Логика ---

# 1. Создание tar.gz архива
if [ -f "$EXCLUDE_FILE" ]; then
    echo "Файл исключений $EXCLUDE_FILE найден. Создаем tar.gz архив с исключениями."
    tar -czvf "$TAR_ARCHIVE_NAME" -C "$BACKUP_DIR" --exclude-from="$EXCLUDE_FILE" .
else
    echo "Файл исключений $EXCLUDE_FILE не найден. Создаем полный tar.gz бэкап."
    tar -czvf "$TAR_ARCHIVE_NAME" -C "$BACKUP_DIR" .
fi

if [ $? -ne 0 ]; then
    echo "Ошибка: Не удалось создать tar.gz архив. Процесс прерван."
    exit 1
fi

# 2. Создание 7z архива
echo "Сжимаем tar.gz архив в 7z с паролем и шифрованием имён файлов..."
7z a -p"$ARCHIVE_PASSWORD" -mhe=on "$FINAL_ARCHIVE_NAME" "$TAR_ARCHIVE_NAME"

if [ $? -ne 0 ]; then
    echo "Ошибка: Не удалось создать 7z архив. Процесс прерван."
    rm "$TAR_ARCHIVE_NAME"
    exit 1
fi

# 3. Проверка размера
# Получаем размер нового 7z-архива в байтах
CURRENT_SIZE=$(stat -c%s "$FINAL_ARCHIVE_NAME")

if [ -f "$LAST_SIZE_FILE" ]; then
    LAST_SIZE=$(cat "$LAST_SIZE_FILE")
else
    LAST_SIZE=0
fi

if [ "$CURRENT_SIZE" == "$LAST_SIZE" ]; then
    echo "Размер архива не изменился. Отправка письма не требуется."
    rm "$TAR_ARCHIVE_NAME"
    rm "$FINAL_ARCHIVE_NAME"
    exit 0
fi

echo "Размер архива изменился. Отправляем письмо."
echo "$CURRENT_SIZE" > "$LAST_SIZE_FILE"

# 4. Отправка по почте
echo "Отправка архива по электронной почте на адрес $RECIPIENT_EMAIL..."

(
    echo -e "Subject: =?UTF-8?B?$(echo -n "$EMAIL_SUBJECT" | base64)?=\nMIME-Version: 1.0\nContent-Type: multipart/mixed; boundary=\"BOUNDARY\"\n\n--BOUNDARY\nContent-Type: text/plain; charset=utf-8\n\n$EMAIL_BODY\n\n--BOUNDARY\nContent-Type: application/x-7z-compressed; name=\"$FINAL_ARCHIVE_NAME\"\nContent-Disposition: attachment; filename=\"$FINAL_ARCHIVE_NAME\"\nContent-Transfer-Encoding: base64\n\n$(base64 "$FINAL_ARCHIVE_NAME")\n--BOUNDARY--\n"
) | msmtp -a default -t "$RECIPIENT_EMAIL"

if [ $? -ne 0 ]; then
    echo "Ошибка: Не удалось отправить письмо."
    exit 1
fi

# 5. Очистка
rm "$TAR_ARCHIVE_NAME"
rm "$FINAL_ARCHIVE_NAME"

echo "Резервное копирование завершено."

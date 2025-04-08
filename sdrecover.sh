#!/bin/bash
# Скрипт для восстановления micri SD карт для работы с одноплатниками.
# Все данные на выбранном устройстве будут удалены!
# Скрипт:
# 1. Отмонтирует все разделы на устройстве.
# 2. Очистит устройство от старых метаданных (wipefs).
# 3. Создаст новую таблицу разделов (msdos).
# 4. Создаст один раздел, занимающий всё устройство.
# 5. Обновит таблицу разделов и отформатирует раздел в FAT32.
# 6. Предложит примонтировать раздел для проверки.
#
# Использование:
# sudo ./sdecover.sh

# Цвета для оформления
RED='\033[0;91m'
GREEN='\033[0;92m'
YELLOW='\033[0;93m'
BLUE='\033[0;94m'
NC='\033[0m'  # No Color

# Функция для отображения разделителя
print_separator() {
    echo -e "${BLUE}------------------------------------------------------------${NC}"
}

# Функция для отображения статуса операции
print_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[✓] Успешно: $1${NC}"
    else
        echo -e "${RED}[✗] Ошибка: $1${NC}"
    fi
}

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Запустите скрипт от имени root (например, через sudo).${NC}"
    exit 1
fi

echo -e "${YELLOW}⚠️  ВНИМАНИЕ: Все данные на выбранном устройстве будут утрачены!${NC}"
print_separator

# 1. Поиск и вывод съёмных устройств в виде таблицы с заголовками
echo -e "${YELLOW}Поиск доступных съёмных устройств:${NC}"
print_separator
printf "%-3s | %-10s | %-3s | %-8s | %s\n" "#" "NAME" "RM" "SIZE" "MODEL"
print_separator

# Получаем вывод lsblk. Формат: NAME, RM, SIZE, MODEL
mapfile -t raw_device_lines < <(lsblk -d -o NAME,RM,SIZE,MODEL)

# Пропускаем заголовок (первую строку) и отбираем только устройства с RM=1
devices=()
for line in "${raw_device_lines[@]:1}"; do
    if [[ $(echo "$line" | awk '{print $2}') == "1" ]]; then
        devices+=("$line")
    fi
done

if [ ${#devices[@]} -eq 0 ]; then
    echo -e "${RED}Съёмных устройств не найдено. Убедитесь, что флешка подключена.${NC}"
    exit 1
fi

# Выводим список устройств с нумерацией
for i in "${!devices[@]}"; do
    line="${devices[$i]}"
    NAME_RAW=$(echo "$line" | awk '{print $1}')
    RM=$(echo "$line" | awk '{print $2}')
    SIZE=$(echo "$line" | awk '{print $3}')
    MODEL=$(echo "$line" | awk '{ for(i=4;i<=NF;i++) printf $i" "; print "" }' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    # Формируем имя с приставкой /dev/
    NAME="/dev/${NAME_RAW}"
    printf "%-3s | %-10s | %-3s | %-8s | %s\n" "$((i+1))" "$NAME" "$RM" "$SIZE" "$MODEL"
done
print_separator
echo -e "${YELLOW}Если нужное устройство не отображается, убедитесь, что флешка подключена.${NC}"
echo

# 2. Выбор устройства по номеру
read -p "Введите # устройства, которое требуется восстановить: " dev_num
if ! [[ "$dev_num" =~ ^[0-9]+$ ]] || [ "$dev_num" -lt 1 ] || [ "$dev_num" -gt "${#devices[@]}" ]; then
    echo -e "${RED}Некорректный номер устройства.${NC}"
    exit 1
fi

# Выбираем строку для выбранного номера
selected_line=$(printf "%s\n" "${devices[@]}" | sed -n "${dev_num}p")
DEV_NAME=$(echo "$selected_line" | awk '{print $1}')
DEVICE="/dev/${DEV_NAME}"
DEVICE_SIZE=$(echo "$selected_line" | awk '{print $3}')
DEVICE_MODEL=$(echo "$selected_line" | awk '{ for(i=4;i<=NF;i++) printf $i" "; print "" }' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

print_separator
echo -e "${RED}Вы уверены, что хотите стереть все данные на ${DEVICE} (${DEVICE_SIZE}): ${DEVICE_MODEL}? [y/N]: ${NC}\c"
read -r CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Операция отменена.${NC}"
    exit 0
fi
print_separator

# 3. Выбор файловой системы для форматирования
echo -e "${YELLOW}Выберите файловую систему для форматирования:${NC}"
print_separator
echo "1 - FAT32 (по умолчанию)"
echo "2 - ext4"
print_separator
read -p "Введите номер файловой системы [1/2]: " fs_choice
if [[ "$fs_choice" == "2" ]]; then
    FS_TYPE="ext4"
else
    FS_TYPE="FAT32"
fi
echo -e "${GREEN}[✓] Выбрана файловая система: ${FS_TYPE}${NC}"
print_separator

# 4. Отмонтирование всех разделов устройства
echo -e "${YELLOW}Отмонтирование разделов на ${DEVICE}...${NC}"
umount ${DEVICE}* 2>/dev/null
print_status "Отмонтирование завершено"

# 5. Очистка метаданных (wipefs)
echo -e "${YELLOW}Очистка метаданных (wipefs)...${NC}"
wipefs -a "$DEVICE"
print_status "Очистка метаданных завершена"

# 6. Создание новой таблицы разделов (msdos)
echo -e "${YELLOW}Создание новой таблицы разделов (msdos)...${NC}"
parted "$DEVICE" mklabel msdos --script
print_status "Новая таблица разделов создана"

# 7. Создание нового раздела, занимающего весь объём устройства
echo -e "${YELLOW}Создание нового раздела...${NC}"
parted -s "$DEVICE" mkpart primary fat32 1MiB 100%
print_status "Новый раздел создан"

# 8. Обновление таблицы разделов
echo -e "${YELLOW}Обновление таблицы разделов...${NC}"
partprobe "$DEVICE"
print_status "Таблица разделов обновлена"

# Ожидание появления нового раздела и его проверка
PARTITION="${DEVICE}1"
sleep 2
if [ ! -b "$PARTITION" ]; then
    echo -e "${YELLOW}Ожидание появления раздела ${PARTITION}...${NC}"
    sleep 2
fi
if [ ! -b "$PARTITION" ]; then
    echo -e "${RED}Раздел ${PARTITION} не найден. Проверьте устройство вручную.${NC}"
    exit 1
fi
echo -e "${GREEN}Новый раздел найден: ${PARTITION}${NC}"
print_separator

# 9. Форматирование раздела (автоматически для ext4 с -F)
echo -e "${YELLOW}Форматирование раздела ${PARTITION} в ${FS_TYPE}...${NC}"
if [ "$FS_TYPE" == "ext4" ]; then
    mkfs.ext4 -F "$PARTITION"
else
    mkfs.vfat -F32 "$PARTITION"
fi
print_status "Форматирование раздела завершено"
print_separator

# 10. Монтирование раздела для проверки и последующее размонтирование
read -p "Хотите примонтировать раздел для проверки? [y/N]: " MOUNT_CHOICE
if [[ "$MOUNT_CHOICE" =~ ^[Yy]$ ]]; then
    MOUNT_POINT="/mnt/usb"
    echo -e "${YELLOW}Монтирование раздела ${PARTITION} в ${MOUNT_POINT}...${NC}"
    mkdir -p "$MOUNT_POINT"
    mount "$PARTITION" "$MOUNT_POINT"
    print_status "Раздел смонтирован"
    
    echo -e "${YELLOW}Содержимое ${MOUNT_POINT}:${NC}"
    ls -la "$MOUNT_POINT"
    
    echo -e "${YELLOW}Размонтирование раздела ${PARTITION}...${NC}"
    umount "$MOUNT_POINT"
    print_status "Размонтирование завершено"
fi

print_separator
echo -e "${GREEN}✅ Флешка ${DEVICE} успешно восстановлена и отформатирована в ${FS_TYPE}!${NC}"
print_separator

exit 0
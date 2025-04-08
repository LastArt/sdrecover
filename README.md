<h1>
  <img src="https://example.com/logo.png" style="vertical-align: middle; width: 48 px; margin-right: 10 px;">
  SD Recover
</h1>

**SD Recover** – это скрипт для восстановления и форматирования флеш-накопителей. 
Скрипт автоматически находит съёмные устройства, выводит их в виде аккуратно отформатированной таблицы, запрашивает у пользователя выбор нужного устройства, 
а затем выполняет процедуры:
- Отмонтирование разделов
- Очистка метаданных (wipefs)
- Создание новой таблицы разделов (msdos)
- Создание единственного раздела на весь объём устройства
- Форматирование в выбранную файловую систему (FAT32 по умолчанию или ext4)

После форматирования скрипт может также автоматически смонтировать раздел для проверки содержимого.

## Требования

- Linux (тестировалось на Ubuntu/Debian)
- Bash (версия 4.x или выше)
- Утилиты: `lsblk`, `parted`, `wipefs`, `mkfs.vfat`, `mkfs.ext4`, `dos2unix` (при необходимости)
- Права суперпользователя (root)

## Установка

### Вариант 1. Клонирование репозитория с GitHub

1. **Клонируйте репозиторий:**

    ```bash
    git clone https://github.com/LastArt/sdrecover.git
    ```
2. **Перейдите в директорию проекта:**

    ```bash
    cd flash-recover
    ```
3. **Запустите скрипт (требуются root-права):**

    ```bash
    sudo bash ./sdrecover.sh
    ```

### Вариант 2. Установка через curl

Одной командой:

> 
> ```bash
> curl -sL https://raw.githubusercontent.com/LastArt/sdrecover/master/sdrecover.sh | sudo bash
> ```


## Важное предупреждение

**ВНИМАНИЕ:** **Все данные на выбранном устройстве будут безвозвратно утрачены!** Перед запуском скрипта убедитесь, что выбран правильный накопитель.




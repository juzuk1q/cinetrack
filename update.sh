#!/usr/bin/env bash
# ==============================================================================
# Скрипт автоматического обновления CineTrack на сервере
# Использование: ./update.sh  (или bash update.sh)
# ==============================================================================

set -e

# Определение рабочей директории проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$SCRIPT_DIR"

echo "================================================="
echo "  🎬 CineTrack: Запуск обновления сайта...       "
echo "================================================="

# 1. Отмена любых случайных локальных изменений и удаление мусора
echo "🧹 Очистка локальных файлов и кэша git..."
git reset --hard HEAD
git clean -fd

# 2. Получение свежей сборки из GitHub
echo "⬇️ Скачивание последней версии из репозитория..."
git pull origin main

# 3. Настройка корректных прав доступа для веб-сервера
echo "🔒 Проверка прав доступа..."
if [ -d "build/web" ]; then
    chmod -R 755 build/web 2>/dev/null || true
fi
chmod +x update.sh 2>/dev/null || true

# 4. Перезагрузка Nginx если он запущен
if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet nginx; then
    echo "🔄 Перезагрузка Nginx конфигурации..."
    systemctl reload nginx 2>/dev/null || true
fi

echo "================================================="
echo "  ✅ Обновление успешно завершено!               "
echo "  📦 Версия: $(git log -1 --pretty=format:'%h — %s')"
echo "  🕒 Дата:   $(git log -1 --pretty=format:'%cd' --date=relative)"
echo "================================================="

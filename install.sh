#!/bin/sh
# Встановлення або оновлення Harno з Термінала / Install or update Harno from Terminal:
#   curl -fsSL https://harno.tehnokrat.ua/install.sh | sh
#
# Що робить скрипт: завантажує останню версію з GitHub, перевіряє підпис, закриває запущений Harno,
# ставить Harno.app у «Програми» (замість старої копії, зокрема «Text Enhancer.app») і запускає його.
# Універсальний доступ скрипт не вмикає — macOS дозволяє це лише вручну: Harno сам попросить доступ
# під час першого запуску й відкриє потрібний розділ налаштувань.
#
# Змінні для перевірки / variables for testing:
#   HARNO_DIR=<тека>    куди встановлювати (типово /Applications, без прав на запис — ~/Applications)
#   HARNO_NO_LAUNCH=1   не запускати після встановлення
set -eu

URL="https://github.com/alexeylg2/text-enhancer-releases/releases/latest/download/Harno.zip"

case "${LANG:-}" in
    uk*|ru*) UA=1 ;;
    *) UA= ;;
esac
say() { if [ -n "$UA" ]; then printf '%s\n' "$1"; else printf '%s\n' "$2"; fi; }
fail() { say "Помилка: $1" "Error: $2" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "Harno працює лише на macOS." "Harno runs on macOS only."
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[ "$MAJOR" -ge 14 ] || fail "потрібна macOS 14 Sonoma або новіша." "macOS 14 Sonoma or later is required."

DIR="${HARNO_DIR:-/Applications}"
if [ -z "${HARNO_DIR:-}" ] && [ ! -w "$DIR" ]; then
    DIR="$HOME/Applications"
fi
mkdir -p "$DIR"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

say "Завантажую Harno…" "Downloading Harno…"
curl -fsSL "$URL" -o "$WORK/Harno.zip" || fail "не вдалося завантажити архів." "couldn't download the archive."
ditto -x -k "$WORK/Harno.zip" "$WORK/unpacked" || fail "не вдалося розпакувати архів." "couldn't unpack the archive."
APP="$(find "$WORK/unpacked" -maxdepth 3 -name 'Harno.app' -type d | head -n 1)"
[ -n "$APP" ] || fail "в архіві немає Harno.app." "Harno.app is missing from the archive."

# Підпис цілий і належить саме Harno — інакше нічого не ставимо.
codesign --verify --deep --strict "$APP" 2>/dev/null || fail "підпис застосунку пошкоджений." "the app signature is broken."
[ "$(defaults read "$APP/Contents/Info" CFBundleIdentifier 2>/dev/null)" = "com.alexeylg.TextEnhancer" ] \
    || fail "в архіві не той застосунок." "the archive contains a different app."

# Закриваємо лише копії з цієї теки, щоб не зачепити інші екземпляри.
for OLD in "$DIR/Harno.app" "$DIR/Text Enhancer.app"; do
    pkill -f "$OLD/Contents/MacOS/" 2>/dev/null && sleep 1 || true
done

say "Встановлюю в ${DIR}…" "Installing to ${DIR}…"
rm -rf "$DIR/Harno.app" "$DIR/Text Enhancer.app"
ditto "$APP" "$DIR/Harno.app"
xattr -dr com.apple.quarantine "$DIR/Harno.app" 2>/dev/null || true

VERSION="$(defaults read "$DIR/Harno.app/Contents/Info" CFBundleShortVersionString) ($(defaults read "$DIR/Harno.app/Contents/Info" CFBundleVersion))"
say "Готово: Harno ${VERSION}." "Done: Harno ${VERSION}."

if [ -z "${HARNO_NO_LAUNCH:-}" ]; then
    open "$DIR/Harno.app"
    say "Harno запущено — значок у рядку меню. Під час першого запуску дозвольте «Універсальний доступ»," \
        "Harno is running — look for its icon in the menu bar. On first launch, allow Accessibility"
    say "а потім додайте ключ API в «Налаштування» → «Моделі» або запустіть LM Studio." \
        "and then add an API key in Settings → Models or start LM Studio."
fi

#!/usr/bin/env bash
set -euo pipefail

# Quick test harness for language loading
# Usage: bash scripts/test-lang.sh

REP_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1090
source "$REP_SCRIPT/function"

echo "REP_SCRIPT=$REP_SCRIPT"

if [ ! -f "$REP_SCRIPT/lang/fr.ini" ] || [ ! -f "$REP_SCRIPT/lang/en.ini" ]; then
    echo "Error: missing lang files in $REP_SCRIPT/lang"
    ls -l "$REP_SCRIPT/lang" || true
    exit 2
fi

echo
echo "---- Testing French (fr_FR) ----"
LC_ALL=fr_FR.UTF-8 LANG=fr_FR.UTF-8 load_language
printf 'MSG_LANGUAGE_DETECTED: %s\n' "${MSG_LANGUAGE_DETECTED:-}" 
printf 'MSG_DISTRO_DETECTED: %s\n' "${MSG_DISTRO_DETECTED:-}" 
printf 'MSG_USER_ADDED_SUCCESS: %s\n' "${MSG_USER_ADDED_SUCCESS:-}" 
printf 'MSG_TITRE: %s\n' "${MSG_TITRE:-}" 

echo
echo "---- Testing English (en_US) ----"
LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 load_language
printf 'MSG_LANGUAGE_DETECTED: %s\n' "${MSG_LANGUAGE_DETECTED:-}" 
printf 'MSG_DISTRO_DETECTED: %s\n' "${MSG_DISTRO_DETECTED:-}" 
printf 'MSG_USER_ADDED_SUCCESS: %s\n' "${MSG_USER_ADDED_SUCCESS:-}" 
printf 'MSG_TITRE: %s\n' "${MSG_TITRE:-}" 

echo
echo "Test finished."

#!/usr/bin/env bash
# Проверка компонента карты в jsdom (без браузера). Нужны Node.js и доступ к npm.
set -e
cd "$(dirname "$0")"
rm -rf .tmp && mkdir -p .tmp
cp ../../frontend/components/russia-outline.js .tmp/russia-outline.mjs
sed "s#'./russia-outline.js'#'./russia-outline.mjs'#" ../../frontend/components/russia-map.js > .tmp/russia-map.mjs
cp russia-map.test.mjs .tmp/
cd .tmp
npm install jsdom --no-save --silent
node russia-map.test.mjs

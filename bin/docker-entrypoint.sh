#!/bin/bash
set -e

# Удаляем старый server.pid если существует
if [ -f /rails/tmp/pids/server.pid ]; then
  rm /rails/tmp/pids/server.pid
fi

echo "Preparing database..."
bundle exec rails db:prepare

echo "Starting Rails server..."
exec "$@"

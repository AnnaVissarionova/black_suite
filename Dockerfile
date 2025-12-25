# Упрощенный Dockerfile для Kamal с отключенным BuildKit
FROM ruby:3.2.3-slim

# Установка зависимостей
RUN apt-get update -qq && \
    apt-get install -y \
    build-essential \
    libpq-dev \
    nodejs \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Рабочая директория
WORKDIR /rails

# Копируем Gemfile и устанавливаем гемы
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Копируем остальное приложение
COPY . .

# Порт
EXPOSE 3000

# Entrypoint для подготовки БД и запуска сервера
COPY bin/docker-entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]

# Команда запуска
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]

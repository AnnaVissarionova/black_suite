# BlackSuite
Веб-приложение для визуализации и анализа результатов оптимизационных экспериментов. Позволяет загружать JSON-файлы с результатами, строить интерактивные 3D-графики, управлять проектами и экспериментами, а также делиться результатами через публичные ссылки. 

## Возможности
- Управление проектами и экспериментами (CRUD операции)

- Загрузка JSON-файлов с результатами оптимизации

- Интерактивная 3D-визуализация с Plotly.js

- Публичный доступ к проектам и экспериментам по ссылке

- Личный кабинет с управлением API-токеном

- REST API для программной загрузки результатов

- Интеграция с ИИ для гибкого построения графиков


## Технологический стек
Backend: Ruby on Rails 8

Frontend: Tailwind CSS, Stimulus, Turbo

Визуализация: Plotly.js

База данных: PostgreSQL


## Установка и запуск
```
# Клонирование репозитория
git clone https://github.com/AnnaVissarionova/black_suite.git
cd black_suite

# Установка зависимостей
bundle install

# Настройка базы данных
rails db:create
rails db:migrate

# Запуск сервера
rails server
```

## API
curl -X POST http://localhost:3000/api/add_experiment_result \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -F "project_id=1" \
  -F "json_file=@result.json" \
  -F "experiment_name=Название эксперимента"

Аутентификация: Devise + API токены

Развертывание: Kamal + Docker

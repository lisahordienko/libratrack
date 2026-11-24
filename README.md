# libratrack

**libratrack** — RESTful-сервіс для управління бібліотечним каталогом, виданими примірниками та позиками читачів. Проєкт побудований на Go та розроблений із акцентом на зрозумілу архітектуру, безпеку, перевірюваність і готовність до розгортання в контейнерному середовищі.

Проєкт поєднує JSON API, веб-інтерфейс на HTMX та PostgreSQL-сховище і демонструє практики backend-розробки рівня реального сервісу: аутентифікацію JWT, RBAC, міграції БД, middleware, валідацію, логування та graceful shutdown.

## Основні можливості

- CRUD для книг, авторів, категорій і фізичних примірників.
- Облік наявності та видачі книг читачам.
- Реєстрація та вхід користувачів через bcrypt і JWT.
- Ролі `reader`, `librarian` і `admin` з правами на окремі endpoint-и.
- Публічний каталог із live-пошуком через HTMX та server-side шаблони.
- Автоматичний пошук міграцій при запуску сервера.
- Вбудовані у бінарник міграції, шаблони та статичні ресурси завдяки `go:embed`.
- CORS, обмеження розміру тіла запиту, відновлення після panic і структуроване логування.
- HTTP і HTTPS режим запуску, налаштовуваний порт і graceful shutdown.

## Технології

| Область | Рішення |
|---|---|
| Мова | Go 1.22 |
| HTTP-фреймворк | Gin |
| База даних | PostgreSQL 16 |
| ORM і міграції | GORM, golang-migrate |
| Аутентифікація | JWT, bcrypt |
| Веб-інтерфейс | HTML templates, HTMX |
| Контейнеризація | Docker Compose |
| Тестування | Go test, race detector |

## Архітектура

Проєкт розділено на окремі шари відповідальності:

```text
cmd/api                 точка входу, конфігурація сервера и lifecycle
internal/app            побудова HTTP-router і wiring залежностей
internal/auth           логіка JWT і аутентифікації
internal/handler        REST і веб-обробники HTTP-запитів
internal/middleware     auth, RBAC, CORS, recovery і limits
internal/model          моделі предметної області
internal/repository     GORM-репозиторії для PostgreSQL
internal/service        бізнес-логіка каталогу і позик
migrations              версіоновані SQL-міграції
web                     embedded шаблони и статичні ресурси
```

Таке розділення спрощує заміну сховища, ізолює HTTP-код від бізнес-логіки і дозволяє перевіряти окремі компоненти без залежності від зовнішнього сервера.

## Швидкий старт

### Вимоги

- Go 1.22 або новіший
- Docker і Docker Compose
- PostgreSQL 16 для повноцінного запуску

### 1. Запуск PostgreSQL

```bash
docker compose up -d postgres
```

За замовчуванням база доступна на `localhost:5432`.

### 2. Налаштування змінних середовища

```bash
export DATABASE_URL='postgres://libratrack:libratrack@localhost:5432/libratrack?sslmode=disable'
export JWT_SECRET='replace-with-a-long-random-secret'
export PORT=8080
```

Для HTTPS додатково задайте:

```bash
export TLS_CERT_FILE=/absolute/path/to/cert.pem
export TLS_KEY_FILE=/absolute/path/to/key.pem
```

`DATABASE_URL` і `JWT_SECRET` є обов'язковими для запуску production-сервера.

### 3. Запуск сервера

Для автоматичного запуску PostgreSQL і локального Go-сервера використайте:

```bash
./scripts/run-local.sh
```

Скрипт читає `.env`, піднімає тільки контейнер `postgres`, чекає готовності бази й запускає API через `go run ./cmd/api`.

Сервіс буде доступний за адресою `http://localhost:8080`.

## Перевірка стану

```bash
curl http://localhost:8080/health
```

Відповідь:

```json
{"status":"ok"}
```

Веб-каталог: `http://localhost:8080/catalog`
Сторінка входу: `http://localhost:8080/web/login`

## REST API

Усі JSON-відповіді використовують `snake_case`. Для захищених endpoint-ів передайте токен у заголовку:

```http
Authorization: Bearer <jwt-token>
```

### Аутентифікація

| Метод | Шлях | Доступ | Опис |
|---|---|---|---|
| `POST` | `/api/v1/auth/register` | public | Створення користувача |
| `POST` | `/api/v1/auth/login` | public | Отримання JWT-токена |
| `GET` | `/api/v1/me` | authenticated | Профіль поточного користувача |
| `PUT` | `/api/v1/me` | authenticated | Оновлення профілю |
| `GET` | `/api/v1/me/loans` | authenticated | Позики поточного користувача |

### Книги та каталог

| Метод | Шлях | Доступ | Опис |
|---|---|---|---|
| `GET` | `/api/v1/books` | public | Список книг із фільтрами й пагінацією |
| `GET` | `/api/v1/books/:id` | public | Деталі книги |
| `GET` | `/api/v1/books/:id/copies` | public | Примірники конкретної книги |
| `GET` | `/api/v1/books/:id/availability` | public | Наявність примірника |
| `POST` | `/api/v1/books` | librarian, admin | Створення книги |
| `PUT` | `/api/v1/books/:id` | librarian, admin | Оновлення книги |
| `DELETE` | `/api/v1/books/:id` | librarian, admin | Видалення книги |
| `POST` | `/api/v1/books/:id/copies` | librarian, admin | Додавання примірника |

### Автори, категорії та позики

| Метод | Шлях | Доступ | Опис |
|---|---|---|---|
| `GET` | `/api/v1/authors` | public | Список авторів |
| `GET` | `/api/v1/authors/:id` | public | Деталі автора |
| `POST` | `/api/v1/authors` | librarian, admin | Створення автора |
| `GET` | `/api/v1/categories` | public | Список категорій |
| `GET` | `/api/v1/categories/:id` | public | Деталі категорії |
| `POST` | `/api/v1/categories` | librarian, admin | Створення категорії |
| `POST` | `/api/v1/loans` | librarian, admin | Оформлення позики |
| `POST` | `/api/v1/loans/:id/return` | librarian, admin | Повернення примірника |
| `GET` | `/api/v1/users` | admin | Список користувачів |
| `PUT` | `/api/v1/users/:id/role` | admin | Зміна ролі користувача |

Приклад входу:

```bash
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"reader@example.test","password":"strong-password"}'
```

### Демо-облікові записи

Після застосування міграцій доступні три seed-акаунти для швидкої локальної демонстрації:

| Роль | Email | Пароль |
|---|---|---|
| Reader | `reader@example.test` | `strong-password` |
| Librarian | `librarian@example.test` | `strong-password` |
| Admin | `admin@example.test` | `strong-password` |

Ці облікові записи призначені лише для локального демо. Перед реальним розгортанням їх слід видалити або замінити окремими паролями.

## Обробка помилок

API повертає структуровані JSON-помилки і не розкриває внутрішні деталі або stack trace:

```json
{
  "error": {
    "code": "not_found",
    "message": "Resource not found"
  }
}
```

HTTP-сервіс використовує відповідні статуси для некоректних запитів, відсутніх ресурсів і помилок сервера. Middleware перетворює непередбачувані panic у безпечну відповідь `500` і записує технічні подробиці в лог.

## Веб-каталог

`/catalog` забезпечує пошук книг із частковим оновленням сторінки через HTMX. Статичні ресурси та HTML-шаблони завантажуються з embedded filesystem, тому для основного запуску не потрібні окремі каталоги шаблонів поруч із бінарником.

## Конфігурація Docker

Compose-файл піднімає PostgreSQL з незмінним життєвим циклом даних завдяки Docker volume:

```bash
docker compose up -d postgres
docker compose down
```

Для повного видалення локальних даних:

```bash
docker compose down -v
```

Основні змінні PostgreSQL:

- `POSTGRES_DB`, за замовчуванням `libratrack`
- `POSTGRES_USER`, за замовчуванням `libratrack`
- `POSTGRES_PASSWORD`, за замовчуванням `libratrack`
- `POSTGRES_PORT`, за замовчуванням `5432`

## Тестування і перевірка якості

```bash
go test -race ./...
go vet ./...
gofmt -l .
```

Комплексні перевірки включають API-контракти, middleware, валідацію, аутентифікацію, RBAC, репозиторії та конкурентну поведінку.

Для запуску окремого набору тестів:

```bash
go test ./internal/app -v
```

## Безпека

- Паролі зберігаються у вигляді bcrypt-хешів.
- JWT підписується через конфігурований секрет `JWT_SECRET`.
- Доступ до адміністративних операцій перевіряється на сервісі RBAC.
- Браузерні кукі входу налаштовані як HttpOnly.
- Форми браузерного входу перевіряються за Same-Origin.
- Тіло запиту обмежене розміром 1 МБ.
- Сервер задає часи на читання, запис і graceful shutdown для захисту від зависання з'єднань.

## Напрямки розвитку

- OpenAPI/Swagger-документація для всіх endpoint-ів.
- Redis-кеш для пошуку й повторюваних запитів.
- Механізм оновлення access/refresh-токенів.
- Метрики Prometheus і структурований журнал у Loki/ELK.

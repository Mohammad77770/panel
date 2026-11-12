ARG PYTHON_VERSION=3.14

# --- مرحله ۱: ساخت داشبورد با Bun ---
FROM oven/bun:latest AS dashboard-builder
WORKDIR /build

# کپی کردن کل سورس‌کد پروژه (شامل پوشه dashboard)
COPY . .

# رفتن به پوشه dashboard، نصب وابستگی‌ها و ساخت
WORKDIR /build/dashboard
RUN bun install --frozen-lockfile || bun install
RUN bun run build

# --- مرحله ۲: ساخت بک‌اند پایتون ---
FROM ghcr.io/astral-sh/uv:python$PYTHON_VERSION-bookworm-slim AS builder
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    python3-dev \
    libc6-dev \
    && rm -rf /var/lib/apt/lists/*

ENV UV_PYTHON_DOWNLOADS=0
WORKDIR /build
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-install-project --no-dev
ADD . /build
RUN uv sync --frozen --no-dev

# --- مرحله ۳: ایمیج نهایی ---
FROM python:$PYTHON_VERSION-slim-bookworm

COPY --from=builder /build /code
# کپی کردن خروجی بیلد داشبورد از مرحله ۱
COPY --from=dashboard-builder /build/dashboard/dist /code/dashboard/dist

WORKDIR /code
ENV PATH="/code/.venv/bin:$PATH"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY cli_wrapper.sh /usr/bin/pasarguard-cli
RUN chmod +x /usr/bin/pasarguard-cli

COPY tui_wrapper.sh /usr/bin/pasarguard-tui
RUN chmod +x /usr/bin/pasarguard-tui

COPY healthcheck.sh /code/healthcheck.sh
RUN chmod +x /code/healthcheck.sh

RUN chmod +x /code/start.sh

ENTRYPOINT ["/code/start.sh"]

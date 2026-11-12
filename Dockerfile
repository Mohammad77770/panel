ARG PYTHON_VERSION=3.14

FROM ghcr.io/astral-sh/uv:python$PYTHON_VERSION-bookworm-slim AS builder
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    python3-dev \
    libc6-dev \
    && rm -rf /var/lib/apt/lists/*

ENV UV_PYTHON_DOWNLOADS=0

WORKDIR /build

# کپی کردن فایل‌های وابستگی به جای استفاده از bind mount
COPY pyproject.toml uv.lock ./

# نصب وابستگی‌ها با استفاده از کش معتبر Railway
RUN --mount=type=cache,id=s/76d75f39-0a35-4f84-86ea-54f3499c9843-/root/.cache/uv,target=/root/.cache/uv \
    uv sync --frozen --no-install-project --no-dev

# کپی کردن کل پروژه و نصب مجدد
ADD . /build
RUN --mount=type=cache,id=s/76d75f39-0a35-4f84-86ea-54f3499c9843-/root/.cache/uv,target=/root/.cache/uv \
    uv sync --frozen --no-dev


FROM python:$PYTHON_VERSION-slim-bookworm

COPY --from=builder /build /code
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

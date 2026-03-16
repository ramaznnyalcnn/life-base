FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV ROOT_DIR=/app
ENV PYTHONPATH=/app/backend

WORKDIR /app

COPY backend/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

COPY backend /app/backend
COPY infra /app/infra
COPY .env.example /app/.env.example

RUN chmod +x /app/infra/scripts/backend-migrate.sh /app/infra/scripts/backend-start.sh

EXPOSE 8000

CMD ["/app/infra/scripts/backend-start.sh"]

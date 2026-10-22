FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PORT=8000
WORKDIR /app
COPY backend/requirements-mysql.txt backend/requirements-hosting.txt ./
RUN pip install --no-cache-dir -r requirements-hosting.txt
COPY backend/server.py backend/mysql_store.py backend/mobile_auth.py backend/host_api.py backend/schema.sql backend/mobile_schema.sql ./
EXPOSE 8000
CMD ["python", "host_api.py"]

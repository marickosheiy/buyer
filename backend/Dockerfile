FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PORT=8000
WORKDIR /app
COPY requirements-mysql.txt requirements-hosting.txt ./
RUN pip install --no-cache-dir -r requirements-hosting.txt
COPY server.py mysql_store.py mobile_auth.py host_api.py schema.sql mobile_schema.sql ./
EXPOSE 8000
CMD ["python", "host_api.py"]

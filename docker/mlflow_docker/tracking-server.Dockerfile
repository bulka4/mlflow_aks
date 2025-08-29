FROM python:3.9-slim

RUN apt-get update && apt-get install -y \
    build-essential \
    default-libmysqlclient-dev \
    gcc \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN pip install mlflow[extras] azure-storage-blob azure-identity pymysql mysqlclient
# Image for running MLflow Tracking Server. Here we install packages needed to run the Tracking Server which uses Azure Storage Account 
# as an artifact store and MySQL as a backend store.

FROM python:3.9-slim

RUN apt-get update && apt-get install -y \
    build-essential \
    default-libmysqlclient-dev \
    gcc \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN pip install mlflow[extras] azure-storage-blob azure-identity pymysql mysqlclient
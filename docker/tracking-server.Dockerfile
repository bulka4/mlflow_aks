FROM python:3.9-slim
RUN pip install mlflow[extras] azure-storage-blob azure-identity pymysql
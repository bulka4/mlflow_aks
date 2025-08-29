FROM python:3.11-slim

# Install sh and git:
# - sh: We run in the job command "sh -c "mlflow...""
# - git: Required to run a MLflow project
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    dash \
    && rm -rf /var/lib/apt/lists/*

COPY mlproject_requirements.txt /root/requirements.txt

RUN pip install -r /root/requirements.txt
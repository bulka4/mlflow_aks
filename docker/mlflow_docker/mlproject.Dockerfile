# Image for running the MLflow project

FROM python:3.11-slim

# Install sh and git:
# - sh: Needed because when deploying a Job running MLflow project, we execute the command "sh -c "mlflow run ...""
# - git: Required to run a MLflow project
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    dash \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Python libraries used in the MLflow project
COPY mlproject_requirements.txt /root/requirements.txt

RUN pip install -r /root/requirements.txt
FROM ubuntu:22.04

# ========== Define build-time variables ==========

# Names of Docker images we will push to ACR and use for deploying:
# - MLflow Tracking Server
# - MLflow project
ARG MLFLOW_SERVER_IMAGE_NAME=${tracking_server_image_name}
ARG MLFLOW_PROJECT_IMAGE_NAME=${mlproject_image_name}
# This prevents prompting user for input for example when using apt-get.
ENV DEBIAN_FRONTEND=noninteractive


# Tell Docker to use bash for the rest of the Dockerfile
SHELL ["/bin/bash", "-c"]



# ========== Prepare folders =============

RUN \
  # The k8s folder we will contain files related to deploying resources on Kubernetes
  mkdir /root/k8s && \
  # The mlflow_docker folder will contain files related to Docker images used by MLflow
  mkdir /root/mlflow_docker && \
  # The mlflow_project folder will contain files related to the MLflow project
  mkdir /root/mlflow_project




# ============ Install Helm, Azure CLI and kubectl =============

# Install Helm
RUN apt-get update && \
    apt-get -y install curl && \
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash


# Install Azure CLI and save credentials to AKS in the ~/.kube/config (kubeconfig) file
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash && \

    # Login to Azure using CLI using the created Service Principal which has proper permissions for using 'az aks get-credentials'
    # and 'az acr build'.
    az login --service-principal \
      --username ${acr_sp_id} \
      --password ${acr_sp_password} \
      --tenant ${tenant_id} && \

    az account set --subscription ${subscription_id} && \

    # Save credentials to AKS in the ~/.kube/config (kubeconfig) file. That will enable us using kubectl to interact with AKS.
    az aks get-credentials \
      --resource-group ${rg_name} \
      --name ${aks_name}


# Install mlflow
RUN apt-get install -y python3 python3-pip python3-venv && \
    python3 -m venv /root/mlflow_project/mlflow-env && \
    source /root/mlflow_project/mlflow-env/bin/activate && \
    pip install mlflow[extras]


# Install kubectl for interacting with AKS
RUN apt-get install -y apt-transport-https ca-certificates && \
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \

    # Add the GPG key and APT repository URL to the kubernetes.list. That url will be used to pull Kubernetes packages (like kubectl)
    <<EOF cat >> /etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /
EOF

RUN apt-get update && \
    apt-get install -y kubectl && \
    apt-mark hold kubectl




# ============ Create and save a bash script for building and pushing to ACR images needed for MLflow =============

# Those images will be used when deploying MLflow resources on AKS. There are two images:
# - For the MLflow Tracking Server
# - For the MLflow project

# Copy files needed building both images
COPY mlflow_docker /root/mlflow_docker


# Save the script for building image and pushing it to ACR.
RUN <<EOF cat > /root/mlflow_docker/build_and_push.sh
az acr build \
  --registry ${acr_name} \
  --resource-group ${rg_name} \
  --image $MLFLOW_SERVER_IMAGE_NAME \
  --file /root/mlflow_docker/tracking-server.Dockerfile \
  /root/mlflow_docker/

az acr build \
  --registry ${acr_name} \
  --resource-group ${rg_name} \
  --image $MLFLOW_PROJECT_IMAGE_NAME \
  --file /root/mlflow_docker/mlproject.Dockerfile \
  /root/mlflow_docker/
EOF

RUN \
    # Remove the '\r' sign from the script
    sed -i 's/\r$//' /root/mlflow_docker/build_and_push.sh && \
    # Make the script executable
    chmod +x /root/mlflow_docker/build_and_push.sh




# ============ Copy folders with the MLflow project and MLflow Helm chart ==============

COPY mlflow_project /root/mlflow_project
COPY helm_charts /root/k8s/helm_charts




# Run the script for building and pushing images to ACR.
CMD ["/root/mlflow_docker/build_and_push.sh"]
# This Dockerfile will be interpolated by Terraform templatefile function. We are using here the following variables for which Terraform will provide a value:
# username
# acr_url
# acr_sp_id
# acr_sp_password
# acr_name
# mlflow_container
# mlflow_storage_account_name
# mlflow_storage_account_access_key
# tenant_id
# subscription_id
# rg_name
# aks_name


FROM ubuntu:22.04

# ============== Define build-time variables==============

# Name of the Kubernetes resource running MySQL
ARG MYSQL_RESOURCE_NAME=mysql
# Name of the Kubernetes namespace where we will be deploying mlflow related resources
ARG NAMESPACE=mlflow
# Name of a Docker image we will push to ACR and use for deploying MLflow resources
ARG MLFLOW_SERVER_IMAGE_NAME=mlflow-server:latest
# Namge of a Docker image after pushing to ACR (it will be used when pulling this image)
ARG MLFLOW_SERVER_ACR_IMAGE_NAME="${acr_url}/$${MLFLOW_SERVER_IMAGE_NAME}"
# Name of the Kubernetes secret we will deploy with values used by MLflow for accessing a backend and artifact store
ARG MLFLOW_SECRET_NAME=mlflow-secrets
# Name of the Kubernetes secret which will be used for pulling images from ACR
ARG ACR_SECRET_NAME=acr-auth
# Name of the PersistentVolumeClaim which will be created to be used by MySQL resource
ARG MYSQL_PVC_NAME=mysql-pvc
# This prevents prompting user for input for example when using apt-get.
ENV DEBIAN_FRONTEND=noninteractive




RUN \
  # Create a new user with a password 'admin'
  useradd -m -s /bin/bash ${username} && \
  echo "${username}:admin" | chpasswd && \
  # The k8s folder we will contain files related to deploying resources on Kubernetes
  mkdir /home/${username}/k8s && \
  # The mlflow_docker folder will contain files related to Docker images used by MLflow
  mkdir /home/${username}/mlflow_docker




# ============ Install necessary tools =============

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




# ============ Create and save a bash script for building and pushing to ACR an image using the tracking-server.Dockerfile =============

# That image will be used when deploying MLflow resources on AKS.

# Copy the tracking-server.Dockerfile for building an image with the MLflow Tracking Server
COPY tracking-server.Dockerfile /home/${username}/mlflow_docker/tracking-server.Dockerfile

# Save the script for building image and pushing it to ACR.
RUN <<EOF cat > /home/${username}/mlflow_docker/tracking_server_build_push.sh
az acr build \
  --registry ${acr_name} \
  --resource-group ${rg_name} \
  --image $MLFLOW_SERVER_IMAGE_NAME \
  --file /home/${username}/mlflow_docker/tracking-server.Dockerfile \
  .
EOF




# =========== Create a manifest for a namespace for MLflow resources ===============

RUN <<EOF cat > /home/${username}/k8s/mlflow_namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
EOF




# =========== Prepare a manifest for a Volume and Volume Claim which will be used by the MySQL resource ==============

# When installing MySQL chart with Helm we will use the following Volume Claim (they will be used by MySQL Pod)
# The 'storageClassName: managed-csi' option causes that data will be stored in an Azure Disk (created on demand when creating this volume)

RUN <<EOF cat > /home/${username}/k8s/mysql_volume.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $MYSQL_PVC_NAME
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: managed-csi
  resources:
    requests:
      storage: 8Gi
EOF




# ============ Prepare a manifest for MLflow Tracking Server ================

# In this YAML manifest we:
# - Deploy in the MLflow namespace
# - Assign the app: mlflow label to created Deployment and Pods
# - Use the $ACR_SECRET_NAME secret for authentication when pulling a Docker Image
# - Use the Docker Image we created and pushed to the ACR earlier in this script for running a Pod
# - Create environment variables in a Pod with values from the $MLFLOW_SECRET_NAME secret created before.
#   They will be used by the MLflow Tracking Server for authentication to the artifact store and backend store. 
# - Run the command for starting the MLflow Tracking Server.

RUN <<EOF cat > /home/${username}/k8s/mlflow_server.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mlflow-server
  namespace: $NAMESPACE
  labels:
    app: mlflow
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mlflow
  template:
    metadata:
      labels:
        app: mlflow
    spec:
      # Get a secret with value for authentication to the ACR.
      imagePullSecrets:
        - name: $ACR_SECRET_NAME
      containers:
      - name: mlflow
        image: $MLFLOW_SERVER_ACR_IMAGE_NAME
        ports:
        - containerPort: 5000
        env:
        - name: AZURE_STORAGE_CONNECTION_STRING
          valueFrom:
            secretKeyRef:
              name: $MLFLOW_SECRET_NAME
              key: AZURE_STORAGE_CONNECTION_STRING
        - name: DB_URI
          valueFrom:
            secretKeyRef:
              name: $MLFLOW_SECRET_NAME
              key: DB_URI
        command: ["mlflow"]
        args:
          [
            "server",
            "--host", "0.0.0.0",
            "--port", "5000",
            "--backend-store-uri", "$(DB_URI)",
            "--artifacts-destination", "wasbs://${mlflow_container}@${mlflow_storage_account_name}.blob.core.windows.net/"
          ]
EOF




# ============== Prepare a manifest for a Service for the MLflow Tracking Server ================

RUN <<EOF cat > /home/${username}/k8s/mlflow_service.yaml
apiVersion: v1
kind: Service
metadata:
  name: mlflow-service
  namespace: $NAMESPACE
spec:
  type: LoadBalancer  # Or use Ingress
  selector:
    app: mlflow
  ports:
  - port: 5000
    targetPort: 5000
EOF




# ============= Create a manifest for deploying a Pod to test connectivity to the Tracking Server =================

# In this Pod we will run a simple Python script to test connectivity to the Tracking Server, logging metrics to the bancked store
# and saving artifacts in the artifact store.

RUN <<EOF cat > /home/${username}/k8s/mlflow_test.yaml
apiVersion: v1
kind: Pod
metadata:
  name: mlflow-test
  namespace: $NAMESPACE
spec:
  imagePullSecrets:
    - name: $ACR_SECRET_NAME
  containers:
    - name: mlflow-client
      image: $MLFLOW_SERVER_ACR_IMAGE_NAME
      command: ["python"]
      args:
        - "-c"
        - |
            import mlflow
            mlflow.set_tracking_uri("http://mlflow-service.mlflow.svc:5000")

            with mlflow.start_run(run_name="connectivity-test"):
                mlflow.log_param("test_param", 123)
                mlflow.log_metric("test_metric", 0.99)

            print("✅ Logged a test run")

            with mlflow.start_run(run_name="artifact-test") as run:
                with open("test.txt", "w") as f:
                    f.write("Hello MLflow!")
                mlflow.log_artifact("test.txt")

            print("✅ Artifact logged")
  restartPolicy: Never
EOF




# ============= Create the k8s/mlflow_deploy.sh script ================

# That script we can run from a container and it will deploy all the Kubernetes resources:
# - namespace
# - MySQL with a volume
# - secret for the Azure Blob Storage and MySQL
# - secret for authentication to ACR
# - MLflow Tracking Server with a Service


RUN <<EOF cat > /home/${username}/k8s/mlflow_deploy.sh
#!/bin/bash

kubectl apply -f /home/${username}/k8s/mlflow_namespace.yaml

kubectl apply -f /home/${username}/k8s/mysql_volume.yaml

# Install MySQL with Helm. It will be used as a backend store for the MLflow Tracking Server.
# Use the existing $MYSQL_PVC_NAME Volume Claim deployed previously.
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm install -n $NAMESPACE $MYSQL_RESOURCE_NAME bitnami/mysql \
--set primary.persistence.existingClaim=$MYSQL_PVC_NAME \
--set primary.persistence.enabled=true \
--set primary.persistence.storageClass=""




# ============== Create secrets for accessing the Azure Blob Storage and MySQL ==============

# Those secrets will be used when deploying MLflow Tracking Server.

# Wait for the secret to exist (optional but safer)
echo "Waiting for MySQL secret to be created..."
for i in {1..24}; do
  if kubectl get secret $MYSQL_RESOURCE_NAME >/dev/null 2>&1; then
    echo "MySQL secret has been created"
    break
  fi
    sleep 5
done

# Define variables
MYSQL_PASSWORD=$(kubectl get secret $MYSQL_RESOURCE_NAME -o jsonpath="{.data.mysql-root-password}" | base64 -d)
MYSQL_URI="mysql://root:$MYSQL_PASSWORD@$MYSQL_RESOURCE_NAME.default.svc.cluster.local:3306/master"

# Deploy a secret
kubectl apply -f - <<'EOF2'
apiVersion: v1
kind: Secret
metadata:
  name: $MLFLOW_SECRET_NAME
  namespace: $NAMESPACE
type: Opaque
stringData:
  AZURE_STORAGE_CONNECTION_STRING: DefaultEndpointsProtocol=https;AccountName=${mlflow_storage_account_name};AccountKey=${mlflow_storage_account_access_key};EndpointSuffix=core.windows.net
  DB_URI: \$MYSQL_URI
EOF2




# ====== Create a secret for authentication to ACR. ======

# This secret will be used in the imagePullSecrets parameter in deployments for authentication when pulling a Docker Image from ACR.

# Here we create a new secret which holds a new value generated based on credentials to the ACR.
# Here it doesn't matter what email we provide as the docker-email parameter.
kubectl create secret docker-registry $ACR_SECRET_NAME \
  --docker-server=${acr_url} \
  --docker-username=${acr_sp_id} \
  --docker-password=${acr_sp_password} \
  --docker-email=unused@example.com \
  --namespace=$NAMESPACE




kubectl apply -f /home/${username}/k8s/mlflow_server.yaml
kubectl apply -f /home/${username}/k8s/mlflow_service.yaml
EOF



    
# Make scripts executable
RUN chmod +x /home/${username}/k8s/mlflow_deploy.sh && \
    chmod +x /home/${username}/mlflow_docker/tracking_server_build_push.sh




# Remove the '\r' sign from scripts
RUN sed -i 's/\r$//' /home/${username}/mlflow_docker/tracking_server_build_push.sh
RUN sed -i 's/\r$//' /home/${username}/k8s/mlflow_namespace.yaml
RUN sed -i 's/\r$//' /home/${username}/k8s/mysql_volume.yaml
RUN sed -i 's/\r$//' /home/${username}/k8s/mlflow_server.yaml
RUN sed -i 's/\r$//' /home/${username}/k8s/mlflow_service.yaml
RUN sed -i 's/\r$//' /home/${username}/k8s/mlflow_test.yaml
RUN sed -i 's/\r$//' /home/${username}/k8s/mlflow_deploy.sh



# Start Docker daemon (DinD) in a background and start a bash shell
# CMD ["sh", "-c", "dockerd --host=tcp://0.0.0.0:2375 --host=unix:///var/run/docker.sock & exec /bin/bash"]
# COPY start.sh /start.sh
# RUN chmod +x /start.sh
# CMD ["/start.sh"]
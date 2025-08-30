import numpy as np
from sklearn.metrics import mean_squared_error, r2_score
import mlflow
import mlflow.sklearn
import argparse

def get_latest_run_id(experiment_name: str) -> str:
    """
    Returns the run ID of the most recent run in the given experiment.
    """
    # Get experiment object by name
    experiment = mlflow.get_experiment_by_name(experiment_name)
    if experiment is None:
        raise ValueError(f"Experiment '{experiment_name}' not found")
    
    # Search runs in descending order of start time
    runs = mlflow.search_runs(
        experiment_ids=[experiment.experiment_id],
        order_by=["start_time DESC"],
        max_results=1
    )
    
    if runs.empty:
        raise ValueError(f"No runs found in experiment '{experiment_name}'")
    
    # Return the run ID of the latest run
    return runs.loc[0, "run_id"]



# -----------------------------
# Parse arguments
# -----------------------------
parser = argparse.ArgumentParser()
parser.add_argument(
    "--experiment_name"
    ,type=str
    ,required=True
    ,help="We will evaluate the model from the latest run from the experiment specified by the experiment_name parameter."
)
args = parser.parse_args()


# -----------------------------
# Load test data (example)
# -----------------------------
np.random.seed(123)
X_test = np.random.rand(20, 1) * 10
y_test = 3 * X_test.squeeze() + 5 + np.random.randn(20) * 2


# -----------------------------
# Load model from MLflow artifact store
# -----------------------------
run_id = get_latest_run_id(args.experiment_name)
model_uri = f"runs:/{run_id}/lasso_model"
loaded_model = mlflow.sklearn.load_model(model_uri)
print(f"Loaded model from {model_uri}")
print(f"MSE: {mse:.2f}, R^2: {r2:.2f}")

# -----------------------------
# Evaluate model
# -----------------------------
y_pred = loaded_model.predict(X_test)
mse = mean_squared_error(y_test, y_pred)
r2 = r2_score(y_test, y_pred)


# -----------------------------
# Log metrics to MLflow backend store
# -----------------------------
mlflow.log_metric("mse", mse)
mlflow.log_metric("r2", r2)
print("Evaluation metrics logged to MLflow backend")

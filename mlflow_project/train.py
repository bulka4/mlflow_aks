import numpy as np
import matplotlib.pyplot as plt
from sklearn.linear_model import Lasso
from sklearn.metrics import mean_squared_error, r2_score
from sklearn.model_selection import train_test_split
import mlflow
import argparse

# -----------------------------
# Parse arguments
# -----------------------------
parser = argparse.ArgumentParser()
parser.add_argument("--alpha", type=float, required=True, help="The alpha parameter for the sklearn.linear_model.Lasso model.")
parser.add_argument("--max_iter", type=int, required=True, help="The max_iter parameter for the sklearn.linear_model.Lasso model.")
args = parser.parse_args()


# -----------------------------
# Generate some sample data
# -----------------------------
np.random.seed(42)
X = np.random.rand(100, 1) * 10   # 100 samples, 1 feature
y = 3 * X.squeeze() + 5 + np.random.randn(100) * 2  # linear relation with noise


# -----------------------------
# Split into train/test
# -----------------------------
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# -----------------------------
# Train Lasso Regression
# -----------------------------
lasso = Lasso(alpha=args.alpha, max_iter=args.max_iter)
lasso.fit(X_train, y_train)

# -----------------------------
# Save model in artifact store
# -----------------------------
mlflow.sklearn.log_model(lasso, artifact_path="lasso_model")

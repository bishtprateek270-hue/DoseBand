"""
DoseBand Model Retraining Pipeline.

Loads empirical datasets (calibration_data.csv and expiry_training_data.csv),
trains the Polynomial Regression Dose Estimation Model and KNN Expiry Classifier,
and serializes both models to disk (.pkl files).
"""

import dose_model
import expiry_checker

def main():
    print("=" * 65)
    print("      DOSEBAND MACHINE LEARNING MODEL RETRAINING PIPELINE      ")
    print("=" * 65)

    # 1. Train Dose Estimation Polynomial Regression Model
    print("\n[1/2] Training Polynomial Regression Dose Estimation Model...")
    d_model, poly, r2, mae = dose_model.train_model(
        csv_path="calibration_data.csv",
        model_path="dose_model.pkl"
    )
    print(f"  --> Dose Model Evaluation: R² Score = {r2:.4f} | MAE = {mae:.2f} ppm*hr")
    print("  --> Serialized 'dose_model.pkl' successfully.")

    # 2. Train Expiry KNN Classifier
    print("\n[2/2] Training KNN Expiry Classifier (k=3)...")
    e_model, accuracy = expiry_checker.train_expiry_classifier(
        csv_path="expiry_training_data.csv",
        model_path="expiry_classifier.pkl"
    )
    print(f"  --> Expiry Model Evaluation: Test Accuracy = {accuracy * 100:.1f}%")
    print("  --> Serialized 'expiry_classifier.pkl' successfully.")

    print("\n" + "=" * 65)
    print("         ALL MODELS SUCCESSFULLY RETRAINED AND VERIFIED        ")
    print("=" * 65)

if __name__ == "__main__":
    main()

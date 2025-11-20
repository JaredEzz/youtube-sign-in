# Cloud Run Backend Deployment Instructions

This document summarizes the steps to deploy your Dart backend to Google Cloud Run and connect it to your Google Sheet.

## 1. Google Cloud Platform (GCP) Console Setup

Before deploying your code, ensure you have completed these steps in your GCP project:

-   **Enable Google Sheets API:**
    -   Go to **APIs & Services > Library**.
    -   Search for "Google Sheets API" and **Enable** it.

-   **Create a Service Account (The "Sheet Writer"):**
    -   Go to **IAM & Admin > Service Accounts**.
    -   Click **Create Service Account** and provide a descriptive name (e.g., `giveaway-writer`).
    -   Once created, click on the service account's email address.
    -   Navigate to the **Keys** tab, click **Add Key > Create new key**, and select **JSON**.
    -   **Download this `service-account.json` file.**
    -   **IMPORTANT:** Ensure this downloaded file is renamed to `dex-tags-1e80efd082ac.json` (if it's not already) and placed directly into your `cloud_run_backend` directory.

-   **Share the Google Sheet:**
    -   Create a **new Google Sheet** where you want to store the form data.
    -   Click the **Share** button in the top right.
    -   Paste the **Service Account Email address** (e.g., `giveaway-writer@your-project.iam.gserviceaccount.com` – found on the "Service Accounts" page in GCP) into the sharing dialog and grant it **Editor** access.
    -   **The Spreadsheet ID** for your sheet has already been updated in `cloud_run_backend/bin/server.dart` to `1WDPGYi_u2rxl1r3RCDwLG32mhwPNuCQMncDTLT_bNyw`.

## 2. Deploying to Google Cloud Run

Follow these steps in your terminal, making sure you are in the `cloud_run_backend` directory.

-   **Navigate to your backend directory:**

-   **Build and Push the Container Image:**
    This command builds your Dart application into a Docker image and pushes it to Google Container Registry. Remember to replace `dex-tags` with your actual Google Cloud Project ID.
    ```bash
    gcloud builds submit --tag gcr.io/dex-tags/giveaway-backend
    ```

-   **Deploy to Cloud Run:**
    After the image is built and pushed, deploy it to Cloud Run. Again, replace `dex-tags` with your Google Cloud Project ID.
    ```bash
    gcloud run deploy giveaway-backend --image gcr.io/dex-tags/giveaway-backend --platform managed --region us-central1 --project dex-tags --allow-unauthenticated
    ```
    (You can change `--region us-central1` to your preferred GCP region if needed.)

## 3. Connect Frontend

Once the Cloud Run deployment is complete, the `gcloud run deploy` command will output a **Service URL**. Copy this URL.

The final step will be to update your `index.html` file to point its form submission to this new Cloud Run service URL.

Let me know when your Cloud Run service is deployed and you have the Service URL!

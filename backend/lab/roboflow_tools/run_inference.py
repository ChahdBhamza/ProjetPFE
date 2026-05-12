from inference_sdk import InferenceHTTPClient
import os

# Connect to Roboflow
client = InferenceHTTPClient(
    api_url="https://serverless.roboflow.com",
    api_key="oesPLELo2uEPnMKXp8dM" # Your API Key
)

def run_test(image_path="test.jpg"):
    if not os.path.exists(image_path):
        print(f"Error: {image_path} not found. Please provide a valid image.")
        return

    # Run the "Detect, Count, and Visualize" workflow
    result = client.run_workflow(
        workspace_name="devileyess-workspace",
        workflow_id="detect-count-and-visualize",
        images={
            "image": image_path
        },
        use_cache=True
    )

    print("Workflow Result:")
    print(result)

if __name__ == "__main__":
    run_test()

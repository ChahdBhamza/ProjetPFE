from inference_sdk import InferenceHTTPClient
import os
from dotenv import load_dotenv
load_dotenv()

# Connect to Roboflow
client = InferenceHTTPClient(
    api_url="https://serverless.roboflow.com",
    api_key=os.getenv("ROBOFLOW_API_KEY") 
)

def run_test(image_path="test.jpg"):
    if not os.path.exists(image_path):
        print(f"Error: {image_path} not found. Please provide a valid image.")
        return

    # Run the "Detect, Count, and Visualize" workflow
    result = client.run_workflow(
        workspace_name=os.getenv("ROBOFLOW_WORKSPACE"),
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

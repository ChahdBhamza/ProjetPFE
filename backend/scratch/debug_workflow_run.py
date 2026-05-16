import os
from inference_sdk import InferenceHTTPClient
import json
import traceback

# Configuration
API_KEY = "oesPLELo2uEPnMKXp8dM"
WORKSPACE = "devileyess-workspace"
WORKFLOW = "custom-workflow-2"
TEST_IMAGE = r"c:\Users\chahd\Desktop\DetectionAppPFE\backend\pro_test_result.jpg"

def debug_run():
    print(f"--- Debugging Roboflow Workflow ---")
    print(f"Workspace: {WORKSPACE}")
    print(f"Workflow ID: {WORKFLOW}")
    print(f"Image Path: {TEST_IMAGE}")
    
    if not os.path.exists(TEST_IMAGE):
        print(f"ERROR: Test image not found at {TEST_IMAGE}")
        return

    client = InferenceHTTPClient(
        api_url="https://serverless.roboflow.com",
        api_key=API_KEY
    )

    try:
        print("Sending request to Roboflow...")
        result = client.run_workflow(
            workspace_name=WORKSPACE,
            workflow_id=WORKFLOW,
            images={"image": TEST_IMAGE},
            use_cache=True
        )

        print("\n--- RAW RESULT ---")
        print(json.dumps(result, indent=2, default=str))
        print("------------------\n")

        # Analyzing the structure
        if isinstance(result, list):
            print(f"Result is a LIST of length {len(result)}")
            if len(result) > 0:
                item = result[0]
                print("First item keys:", item.keys())
                
                # Check for standard prediction keys
                # Different workflows might have different output node names
                # In workflows, you define the output names. 
                # If the user's code expects 'predictions', let's check if it's there.
                
                predictions = item.get("predictions", [])
                print(f"Found 'predictions' key: {'Yes' if 'predictions' in item else 'No'}")
                print(f"Number of predictions: {len(predictions) if isinstance(predictions, list) else 'N/A'}")
                
                # Often workflows return outputs based on the node names in the graph
                # Let's list all keys to help the user identify the correct output node
                for key, value in item.items():
                    if isinstance(value, list):
                        print(f"Key '{key}' has {len(value)} items")
                    else:
                        print(f"Key '{key}' value: {value}")
        else:
            print(f"Result is a {type(result)}")
            print("Keys:", result.keys() if hasattr(result, 'keys') else "No keys")

    except Exception as e:
        print("\n!!! ERROR RUNNING WORKFLOW !!!")
        print(f"Exception Type: {type(e).__name__}")
        print(f"Exception Message: {str(e)}")
        traceback.print_exc()

if __name__ == "__main__":
    debug_run()

import sys
import traceback

print("Using Python:", sys.executable)
try:
    # 1. Import the library
    from inference_sdk import InferenceHTTPClient

    # 2. Connect to your workflow
    client = InferenceHTTPClient(
        api_url="https://serverless.roboflow.com",
        api_key="oesPLELo2uEPnMKXp8dM"
    )

    # We need a dummy image or a path. Let's use an empty one or a real one from the project.
    import os
    img_path = r"c:\Users\chahd\Desktop\DetectionAppPFE\backend\sessions\lab_2f32d0ab\processed\frame_0010.jpg"
    if not os.path.exists(img_path):
        print(f"Image {img_path} not found. Please provide a valid path.")
        sys.exit(1)

    print("Running workflow on:", img_path)
    # 3. Run your workflow on an image
    result = client.run_workflow(
        workspace_name="devileyess-workspace",
        workflow_id="custom-workflow-2",
        images={
            "image": img_path
        },
        use_cache=True
    )

    # 4. Get your results
    print("RESULTS:")
    print(result)

except ImportError:
    print("IMPORT ERROR: The module 'inference_sdk' is not installed in this Python environment.")
except Exception as e:
    print("ERROR RUNNING WORKFLOW:")
    traceback.print_exc()

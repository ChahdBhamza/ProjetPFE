# Cybersight PFE: Backend & Flutter Integration Roadmap

This document outlines the professional implementation strategy for connecting the Cybersight Flutter Mobile App with the FastAPI/RAG Backend.

---

## 🏗️ Architecture Overview
We use a **Layered Architecture** to ensure that changes in the AI backend don't break the mobile application.

1. **Presentation Layer (Flutter UI)**: The "Cybersight" HUD and pages.
2. **Domain/Service Layer (Flutter Logic)**: The models and network services.
3. **API Gateway (FastAPI)**: The bridge between mobile and AI.
4. **Logic Layer (Python Services)**: RAG, OCR, and VLM services.

---

## 📅 Phase 1: Data Modeling (Status: ✅)
Define the "Language" both systems speak.
- **Task**: Create Dart classes that map to the JSON responses from Python.
- **Files**: `lib/features/app/data/models/detection_result_model.dart`
- **Flexibility**: If you add new metadata (e.g., Energy Class) in Python, simply add it to this model.

## 📡 Phase 2: Networking Layer (Status: ✅)
Establish the "Neural Link" between phone and computer.
- **Task**: Set up a `Dio` client configured for multipart image uploads.
- **Base URL**: Set to your local machine IP (e.g., `http://192.168.100.5:8000`).
- **Files**: `lib/core/network/api_service.dart`

## 🧠 Phase 3: State Management (Next Step 🛠️)
Handle how the UI reacts to backend events.
- **States to Handle**:
    - `Initial`: Waiting for user input.
    - `Loading`: Image is being sent (Spinning HUD).
    - `Success`: Results are received and mapped to the UI.
    - `Error`: Connection failure or AI timeout.
- **Tool**: Recommended to use `ChangeNotifier` or `Provider` for simple, professional state handling.

## 🛠️ Phase 4: Backend Modularization
Clean up the Python code for a professional PFE submission.
- **Task 1**: Move route logic from `main.py` into dedicated routers (`app/api/endpoints.py`).
- **Task 2**: Use **Pydantic Schemas** for input validation.
- **Task 3**: Ensure all secrets (API Keys) are kept in the `.env` file.

## 🧪 Phase 5: Testing & Validation
- **Network Check**: Verify phone and computer are on the same Wi-Fi.
- **Firewall Check**: Ensure port 8000 is open on the host machine.
- **RAG Verification**: Test the full loop: `Photo -> OCR -> Vector Search -> Result Display`.

---

## 🔄 How to handle changes
If you modify your Python AI logic:
1. **Change Python**: Update the logic in your services.
2. **Update JSON**: If the output format changes, update the `fromJson` factory in Flutter.
3. **Hot Reload**: Flutter will immediately reflect the new data structure.

---
*Created for Cybersight PFE - April 2026*

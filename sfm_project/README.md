# SFM Equipment Identifier

## Quick start (2 commands)

### 1. Backend
```bash
cd backend
pip install -r requirements.txt
cp .env.example .env        # then fill in your API keys
uvicorn main:app --reload --port 8000
```

### 2. Frontend
Just open `frontend/index.html` in your browser. No build step, no npm.

---

## API keys needed

| Key | Where to get | Cost |
|-----|-------------|------|
| `ANTHROPIC_API_KEY` | console.anthropic.com | pay-per-use |
| `SERPER_API_KEY` | serper.dev | free 2500 queries/month |

---

## How to use the web app

1. Drop a video frame (JPG/PNG) into the upload zone
2. Click **Detect & identify** — OpenCV draws a bounding box, both images go to the LLM
3. See model candidates with confidence scores — click to select one
4. Click **Fetch specs** — web search + LLM extracts structured specs
5. Ask the maintenance assistant anything about the equipment
6. Download the JSON report

---

## Project structure
```
sfm_project/
├── backend/
│   ├── main.py              # FastAPI app — 3 endpoints
│   ├── frame_detector.py    # OpenCV bbox + LLM vision (Claude)
│   ├── spec_retriever.py    # Serper search + LLM extraction
│   ├── chat_assistant.py    # Grounded Q&A chat
│   ├── requirements.txt
│   └── .env.example
└── frontend/
    └── index.html           # Full web UI — single file, no framework
```

## Endpoints
| Method | Route | What it does |
|--------|-------|-------------|
| GET | `/health` | Check API keys are set |
| POST | `/identify` | Frame → CV bbox + LLM identification |
| POST | `/specs` | Confirmed model → web search + structured JSON |
| POST | `/chat` | Message + specs + history → grounded answer |

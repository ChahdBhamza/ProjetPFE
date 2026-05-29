# Groq LLM Model Versions Log

This document tracks the evolution of the Large Language Models (LLMs) used within our backend services for forensic analysis and specification extraction. We rely on the Groq API for ultra-low latency inference.

## Current Models (Active)

To optimize for rate limits, API constraints, and speed without sacrificing accuracy, we are currently deploying the following models:

| Service | Active Model | Purpose | Why this model? |
| :--- | :--- | :--- | :--- |
| **Specification Extraction** (`spec_service.py`) | `llama-3.1-8b-instant` | Web scraping, data structuring, and schema-aware JSON extraction. | Extremely fast and lightweight. Easily adheres to structured JSON schemas without hitting the restrictive rate limits of the larger 70B models on the Groq free tier. |
| **Forensic Vision ID** (`frame_detector.py`) | `meta-llama/llama-4-scout-17b-16e-instruct` | Two-pass visual analysis (Brand recognition, model detection, and visual cue extraction). | A highly capable multimodal/vision model available via Groq. Provides the necessary visual reasoning to read blurry text and recognize specific design traits on equipment. |

---

## Previous Models (Archived)

During initial development and prototyping, we tested larger models which provided high intelligence but proved unscalable for real-time extraction due to rate limiting.

| Service | Previous Model | Reason for Change |
| :--- | :--- | :--- |
| **Specification Extraction** (`spec_service.py`) | `llama-3.3-70b-versatile` | This model was exceptionally smart at deducing complex specifications from messy HTML. However, its size meant we frequently hit Groq's token/request rate limits (`429 Rate Limit Exceeded`), causing the extraction pipeline to crash. We migrated to `llama-3.1-8b-instant` for better stability and throughput. |

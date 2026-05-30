# Groq LLM Model Versions Log

This document tracks the evolution of the Large Language Models (LLMs) used within our backend services for forensic analysis and specification extraction. We rely on the Groq API for ultra-low latency inference.

## Current Models (Active)

| Service | Active Model | Purpose | Why this model? |
| :--- | :--- | :--- | :--- |
| **Specification Extraction** (`spec_service.py`) | `llama-3.1-8b-instant` | Web scraping, data structuring, and schema-aware JSON extraction. | Fast and lightweight. Prompt size is carefully controlled (see §Rate Limit Fix) to stay under the 6 000 TPM hard limit. |
| **Forensic Vision ID** (`frame_detector.py`) | `meta-llama/llama-4-scout-17b-16e-instruct` | Two-pass visual analysis (brand recognition, model detection, visual cue extraction). | Capable multimodal/vision model on Groq. Provides the visual reasoning needed to read blurry text and recognize design traits on equipment. |

---

## Rate Limit Fix — 413 "Request Too Large" (2026-05-29)

### Root Cause

The spec extraction prompt was sending ~6 020 tokens in a single request (prompt + `max_tokens=2500` output reservation), which hit the `llama-3.1-8b-instant` 6 000 TPM hard cap.

### Solution Applied (prompt trimming — NOT a model switch)

Three changes to `spec_service.py` that together reduce total tokens from ~6 020 → ~3 300:

| Change | Before | After | Token saving |
|:---|:---|:---|:---|
| Scraped content cap | 7 000 chars (~1 750t) | **4 000 chars (~1 000t)** | −750 tokens |
| Schema JSON format | `indent=2` (~800t) | **`separators=(',',':')` (~500t)** | −300 tokens |
| Output reservation | `max_tokens=2500` | **`max_tokens=1500`** | −1 000 tokens |

**Total saved: ~2 050 tokens** → request now fits comfortably under the 6 000 TPM limit.

---

## Previous Models (Archived)

| Service | Previous Model | Reason for Change |
| :--- | :--- | :--- |
| **Specification Extraction** (`spec_service.py`) | `llama-3.3-70b-versatile` | Much smarter at deducing specs from messy HTML, but its size caused frequent `429 Rate Limit Exceeded` (RPM) errors in real-world bursts. Reverted to `llama-3.1-8b-instant` with prompt trimming as the stable production choice. |

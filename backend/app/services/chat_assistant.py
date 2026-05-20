import json
import time
from openai import OpenAI


SYSTEM_PROMPT = """
You are an expert maintenance assistant at SFM Technologies.
Answer questions based on these technical specs:
{specs_json}

Rules:
- Be concise and practical (technician is in the field)
- Never invent specifications or part numbers
- If unknown, say so clearly rather than guessing
"""


def chat(user_message: str, specs: dict, history: list[dict], api_key: str) -> dict:
    client = OpenAI(
        base_url="https://openrouter.ai/api/v1",
        api_key=api_key,
        default_headers={
            "HTTP-Referer": "http://localhost:8000",
            "X-Title": "SFM Equipment Identifier",
        }
    )

    system = SYSTEM_PROMPT.format(specs_json=json.dumps(specs, indent=2, ensure_ascii=False))

    messages = [{"role": "system", "content": system}]
    for h in history:
        role = "user" if h["role"] == "user" else "assistant"
        messages.append({"role": role, "content": h["content"]})

    messages.append({"role": "user", "content": user_message})

    for attempt in range(3):
        try:
            response = client.chat.completions.create(
                model="google/gemini-3.1-flash-lite",
                messages=messages,
                temperature=0.2,
                max_tokens=2000,
            )
            break
        except Exception as e:
            if "429" in str(e) and attempt < 2:
                time.sleep(5)
                continue
            raise

    reply = response.choices[0].message.content.strip()

    updated_history = history + [
        {"role": "user", "content": user_message},
        {"role": "assistant", "content": reply}
    ]

    return {
        "reply": reply,
        "updated_history": updated_history
    }

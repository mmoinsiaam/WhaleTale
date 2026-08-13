from typing import List, Optional
from openai import OpenAI
from app.config import openai_api_key
from app.services.rag import HistoryTurn

client = OpenAI(api_key=openai_api_key)

def generate_response(query: str, context: str, history: Optional[List[HistoryTurn]] = None):
    system_prompt = ("You are a marine biology expert assistant. Use the context provided to answer the user's question. Prefer the provided context when it's "
    "relevant, but you may also use your own marine biology knowledge to answer fully. "
    "Only answer questions about marine biology, for anything else, politely decline "
    "and explain that you only answer marine biology questions." 
    )

    user_prompt = f"Context: {context}\n\nUser Query: {query}\n\nAnswer:"

    messages = [{"role": "system", "content": system_prompt}]

    if history:
        for turn in history[-4:]:
            messages.append({"role": "user", "content": turn.query})
            messages.append({"role": "assistant", "content": turn.answer})

    messages.append({"role": "user", "content": user_prompt})

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=messages
    )

    return {
        "answer": response.choices[0].message.content,
        "usage": {
            "prompt_tokens": response.usage.prompt_tokens,
            "completion_tokens": response.usage.completion_tokens,
            "total_tokens": response.usage.total_tokens
        }
    }

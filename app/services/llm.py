from typing import List, Optional
from openai import OpenAI
from app.config import openai_api_key
from app.schema.models import HistoryTurn

client = OpenAI(api_key=openai_api_key)

# This function rewrites a follow-up query into a standalone question using the conversation history
def rewrite_query_with_history(query: str, history: Optional[List[HistoryTurn]] = None) -> str:
    if not history:
        return query

    recent = history[-2:]
    history_text = "\n".join(f"Q: {h.query}\nA: {h.answer}" for h in recent)

    rewrite_prompt = (
        "Given this conversation history and a follow-up question, rewrite the "
        "follow-up as a standalone question that includes any implied subject "
        "(e.g. resolve pronouns like 'it', 'their', 'that'). Only output the rewritten question.\n\n"
        f"History:\n{history_text}\n\nFollow-up: {query}\n\nStandalone question:"
    )

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": rewrite_prompt}],
        max_tokens=60,
        temperature=0,
    )
    return response.choices[0].message.content.strip()

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

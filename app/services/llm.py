from openai import OpenAI
from app.config import openai_api_key

client = OpenAI(api_key=openai_api_key)

def generate_response(query: str, context: str) -> str:
    system_prompt = "You are a marine biology expert assistant. Prefer the provided context when it's "
    "relevant, but you may also use your own marine biology knowledge to answer fully. "
    "Only answer questions about marine biology, for anything else, politely decline "
    "and explain that you only answer marine biology questions."

    user_prompt = f"Context: {context}\n\nUser Query: {query}\n\nAnswer:"

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ]
    )
    return response.choices[0].message.content

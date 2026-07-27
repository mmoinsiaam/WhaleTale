from openai import OpenAI
from app.config import openai_api_key

client = OpenAI(api_key=openai_api_key)
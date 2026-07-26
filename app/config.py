#centralizes loading vars

import os
from dotenv import load_dotenv

load_dotenv()

redis_url = os.getenv("REDIS_URL")
openai_api_key = os.getenv("OPEN_AI_API_KEY")

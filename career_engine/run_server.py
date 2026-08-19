"""Convenience entrypoint: python run_server.py"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import uvicorn

from api import config

if __name__ == "__main__":
    uvicorn.run("api.app:app", host=config.HOST, port=config.PORT, reload=True)

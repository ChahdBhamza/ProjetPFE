from fastapi import APIRouter

from app.api.routers import auth
from app.api.routers import inventory
from app.api.routers import search
from app.api.routers import video

api_router = APIRouter()

api_router.include_router(auth.router)
api_router.include_router(inventory.router)
api_router.include_router(search.router)
api_router.include_router(video.router)

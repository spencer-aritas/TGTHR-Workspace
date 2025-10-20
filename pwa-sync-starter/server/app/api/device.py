
from fastapi import APIRouter
router = APIRouter()

@router.get('/device/hello')
def hello():
  return {'ok': True}

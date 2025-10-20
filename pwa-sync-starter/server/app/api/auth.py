from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import requests
import os

router = APIRouter(prefix="/api/auth", tags=["auth"])

@router.get("/oauth-config")
async def get_oauth_config():
    """Get OAuth configuration for frontend"""
    env = os.getenv('SF_ENV', 'benefits')
    
    if env == 'benefits':
        client_id = os.getenv('SF_BENEFITS_JWT_CONSUMER_KEY')
        login_url = os.getenv('SF_BENEFITS_JWT_LOGIN_URL', 'https://test.salesforce.com')
    else:
        client_id = os.getenv('SF_PROD_JWT_CONSUMER_KEY')
        login_url = os.getenv('SF_PROD_JWT_LOGIN_URL', 'https://login.salesforce.com')
    
    if not client_id:
        raise HTTPException(status_code=500, detail="OAuth not configured")
    
    return {"clientId": client_id, "loginUrl": login_url}

class OAuthCallback(BaseModel):
    code: str

@router.post("/oauth-callback")
async def handle_oauth_callback(data: OAuthCallback):
    """Exchange OAuth code for access token and user info"""
    
    env = os.getenv('SF_ENV', 'benefits')
    redirect_uri = 'http://localhost:5173/auth/callback'
    
    if env == 'benefits':
        client_id = os.getenv('SF_BENEFITS_JWT_CONSUMER_KEY')
        client_secret = os.getenv('SF_BENEFITS_JWT_CONSUMER_SECRET')
        token_url = 'https://test.salesforce.com/services/oauth2/token'
    else:
        client_id = os.getenv('SF_PROD_JWT_CONSUMER_KEY')
        client_secret = os.getenv('SF_PROD_JWT_CONSUMER_SECRET')
        token_url = 'https://login.salesforce.com/services/oauth2/token'
    
    if not client_id or not client_secret:
        raise HTTPException(status_code=500, detail="OAuth not configured")
    
    try:
        # Exchange code for access token
        token_response = requests.post(token_url, {
            'grant_type': 'authorization_code',
            'client_id': client_id,
            'client_secret': client_secret,
            'redirect_uri': redirect_uri,
            'code': data.code
        })
        
        if not token_response.ok:
            raise HTTPException(status_code=400, detail="Failed to exchange OAuth code")
            
        token_data = token_response.json()
        access_token = token_data['access_token']
        instance_url = token_data['instance_url']
        
        # Get user info
        user_response = requests.get(f"{instance_url}/services/oauth2/userinfo", 
                                   headers={'Authorization': f'Bearer {access_token}'})
        
        if not user_response.ok:
            raise HTTPException(status_code=400, detail="Failed to get user info")
            
        user_data = user_response.json()
        
        return {
            "user": {
                "id": user_data['user_id'],
                "name": user_data['name'],
                "email": user_data['email'],
                "sfUserId": user_data['user_id']
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"OAuth failed: {str(e)}")
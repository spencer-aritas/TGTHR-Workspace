from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import requests
import os

router = APIRouter(prefix="/api/auth", tags=["auth"])

@router.get("/oauth-config")
async def get_oauth_config():
    """Get OAuth configuration for frontend"""
    try:
        env = os.getenv('SF_ENV', 'benefits')
        print(f"Current SF_ENV: {env}")
        
        if env == 'benefits':
            client_id = os.getenv('SF_BENEFITS_JWT_CONSUMER_KEY')
            login_url = 'https://tgthrnpc--benefits.sandbox.my.salesforce.com'
            print(f"Benefits mode - Client ID: {client_id}")
            print(f"Benefits mode - Login URL: {login_url}")
            print(f"All env vars for debugging:")
            for k, v in os.environ.items():
                if 'SF_' in k:
                    print(f"{k}: {v}")
        else:
            client_id = os.getenv('SF_PROD_JWT_CONSUMER_KEY')
            login_url = os.getenv('SF_PROD_JWT_LOGIN_URL', 'https://tgthrnpc.my.salesforce.com')
            print(f"Prod mode - Client ID: {client_id}")
            print(f"Prod mode - Login URL: {login_url}")
        
        if not client_id:
            error_msg = "OAuth not configured: Missing client ID"
            print(error_msg)
            raise HTTPException(status_code=500, detail=error_msg)
        
        config = {"clientId": client_id, "loginUrl": login_url}
        print(f"Returning OAuth config: {config}")
        return config
        
    except Exception as e:
        import traceback
        error_msg = f"OAuth configuration error: {str(e)}\n{traceback.format_exc()}"
        print(f"Error in get_oauth_config: {error_msg}")
        raise HTTPException(status_code=500, detail=error_msg)

class OAuthCallback(BaseModel):
    code: str

@router.post("/oauth-callback")
async def handle_oauth_callback(data: OAuthCallback):
    """Exchange OAuth code for access token and user info"""
    
    env = os.getenv('SF_ENV', 'benefits')
    print(f"OAuth callback - Environment: {env}")
    
    # Use the redirect URI from the frontend
    redirect_uri = f"{os.getenv('APP_BASE_URL', 'http://localhost:5173')}/auth/callback"
    print(f"OAuth callback - Using redirect URI: {redirect_uri}")
    
    if env == 'benefits':
        client_id = os.getenv('SF_BENEFITS_JWT_CONSUMER_KEY')
        client_secret = os.getenv('SF_BENEFITS_JWT_CONSUMER_SECRET')
        instance_domain = 'tgthrnpc--benefits.sandbox.my.salesforce.com'
    else:
        client_id = os.getenv('SF_PROD_JWT_CONSUMER_KEY')
        client_secret = os.getenv('SF_PROD_JWT_CONSUMER_SECRET')
        instance_domain = 'tgthrnpc.my.salesforce.com'
    
    token_url = f'https://{instance_domain}/services/oauth2/token'
    print(f"Using token URL: {token_url}")
    
    if not client_id or not client_secret:
        raise HTTPException(status_code=500, detail="OAuth not configured")
    
    try:
        # Log the token exchange request details
        token_request_data = {
            'grant_type': 'authorization_code',
            'client_id': client_id,
            'client_secret': client_secret,
            'redirect_uri': redirect_uri,
            'code': data.code
        }
        print(f"Token exchange request to {token_url}")
        print(f"Request data: {token_request_data}")
        
        # Exchange code for access token
        try:
            token_response = requests.post(token_url, token_request_data)
            token_response.raise_for_status()  # This will raise an exception with the response content
        except requests.exceptions.RequestException as e:
            error_msg = str(e)
            if hasattr(e, 'response') and e.response is not None:
                try:
                    error_msg = e.response.json()
                except:
                    error_msg = e.response.text
            print(f"Token exchange failed with URL {token_url}")
            print(f"Request data: {token_request_data}")
            print(f"Error response: {error_msg}")
            raise HTTPException(status_code=400, detail=str(error_msg))
            
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
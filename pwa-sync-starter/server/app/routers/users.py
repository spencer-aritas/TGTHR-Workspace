from fastapi import APIRouter, HTTPException
from typing import List
from pydantic import BaseModel
import jwt
import os
import requests

router = APIRouter(prefix="/api/users", tags=["users"])

class OutreachUser(BaseModel):
    id: str
    name: str
    email: str
    sfUserId: str

@router.get("/outreach", response_model=List[OutreachUser])
async def get_outreach_users():
    """Get list of outreach users from Salesforce"""
    try:
        # Get JWT token for Salesforce
        env = os.getenv('SF_ENV', 'benefits')
        
        if env == 'benefits':
            client_id = os.getenv('SF_BENEFITS_JWT_CONSUMER_KEY')
            username = os.getenv('SF_BENEFITS_JWT_USERNAME')
            private_key_path = os.getenv('SF_BENEFITS_JWT_PRIVATE_KEY_PATH', '../jwt_private.key')
            token_url = 'https://tgthrnpc--benefits.sandbox.my.salesforce.com/services/oauth2/token'
        else:
            client_id = os.getenv('SF_PROD_JWT_CONSUMER_KEY')
            username = os.getenv('SF_PROD_JWT_USERNAME')
            private_key_path = os.getenv('SF_PROD_JWT_PRIVATE_KEY_PATH', '../jwt_private.key')
            token_url = 'https://tgthrnpc.my.salesforce.com/services/oauth2/token'

        with open(private_key_path, 'r') as key_file:
            private_key = key_file.read()
            
        # Create JWT assertion
        now = int(jwt.utils.get_int_from_datetime(jwt.utils.datetime.datetime.now()))
        claim = {
            'iss': client_id,
            'sub': username,
            'aud': token_url,
            'exp': now + 300  # 5 minutes
        }
        
        assertion = jwt.encode(claim, private_key, algorithm='RS256')
        
        # Get access token
        token_response = requests.post(token_url, data={
            'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion': assertion
        })
        
        if not token_response.ok:
            raise HTTPException(status_code=500, detail="Failed to get Salesforce access token")
            
        access_token = token_response.json()['access_token']
        instance_url = token_response.json()['instance_url']
        
        # Query Salesforce for users
        query = """
            SELECT Id, Name, Email 
            FROM User 
            WHERE IsActive = true 
            AND Profile.Name LIKE '%Outreach%'
        """
        
        headers = {
            'Authorization': f'Bearer {access_token}',
            'Content-Type': 'application/json'
        }
        
        response = requests.get(
            f"{instance_url}/services/data/v57.0/query",
            params={'q': query},
            headers=headers
        )
        
        if not response.ok:
            raise HTTPException(status_code=500, detail="Failed to query Salesforce users")
            
        users = []
        for record in response.json().get('records', []):
            users.append(OutreachUser(
                id=record['Id'],
                name=record['Name'],
                email=record['Email'],
                sfUserId=record['Id']
            ))
            
        return users
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get users: {str(e)}")
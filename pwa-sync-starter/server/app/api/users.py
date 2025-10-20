# server/app/api/users.py
from fastapi import APIRouter, HTTPException
from typing import List, Dict, Any
import logging

from ..salesforce.sf_client import query_soql, SFAuthError, SFError

logger = logging.getLogger("users")

router = APIRouter(tags=["users"])

@router.get('/users/outreach')
async def get_outreach_users() -> List[Dict[str, Any]]:
    """Get active Salesforce users for outreach team"""
    try:
        # Query active users - customize this SOQL for your org
        soql = """
            SELECT Id, Name, Email, Username
            FROM User 
            WHERE IsActive = TRUE 
            AND Profile.Name LIKE '%Outreach%'
            ORDER BY Name
        """
        
        # Fallback query if no Outreach profile exists
        try:
            result = query_soql(soql)
        except (SFError, SFAuthError):
            # Fallback: get all active users (you can customize this)
            soql = """
                SELECT Id, Name, Email, Username
                FROM User 
                WHERE IsActive = TRUE 
                AND UserType = 'Standard'
                ORDER BY Name
                LIMIT 20
            """
            result = query_soql(soql)
        
        users = []
        for record in result.get('records', []):
            users.append({
                'id': record['Id'],
                'name': record['Name'],
                'email': record['Email'],
                'sfUserId': record['Id']
            })
        
        return users
        
    except Exception as e:
        logger.error(f"Failed to fetch outreach users: {e}")
        # Return empty list instead of error to allow app to work offline
        return []
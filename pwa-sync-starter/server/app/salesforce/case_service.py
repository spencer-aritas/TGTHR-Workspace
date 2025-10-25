# server/app/salesforce/case_service.py
import logging
from typing import Dict, Any, List
from .sf_client import SalesforceClient

logger = logging.getLogger("case_service")

class CaseService:
    """Service for managing Salesforce Cases"""
    
    def __init__(self):
        self.sf_client = SalesforceClient()
    
    def get_active_cases_for_user(self, user_id: str) -> List[Dict[str, Any]]:
        """Get active cases assigned to a specific user"""
        try:
            logger.info(f"Fetching active cases for user: {user_id}")
            
            query = """
            SELECT Id, CaseNumber, AccountId, Account.Id, Account.Name,
                   Contact.Id, Contact.Name, Status, Subject
            FROM Case 
            WHERE OwnerId = :userId 
            AND Status IN ('New', 'Working', 'Escalated', 'In Progress', 'Active')
            ORDER BY CreatedDate DESC
            LIMIT 100
            """
            
            result = self.sf_client.query(query, {"userId": user_id})
            
            cases = []
            for record in result.get('records', []):
                account = record.get('Account') or {}
                cases.append({
                    'Id': record.get('Id'),
                    'CaseNumber': record.get('CaseNumber'),
                    'AccountId': record.get('AccountId'),
                    'Account': {
                        'Id': account.get('Id'),
                        'Name': account.get('Name')
                    } if account else None,
                    'Status': record.get('Status'),
                    'Subject': record.get('Subject')
                })
            
            logger.info(f"Found {len(cases)} active cases for user {user_id}")
            return cases
            
        except Exception as e:
            logger.error(f"Failed to fetch cases for user {user_id}: {e}")
            raise

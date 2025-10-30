// Direct API call - let individual components handle offline logic
export const postSync = async (endpoint: string, payload: any) => {
  const API_BASE = import.meta.env.VITE_TGTHR_API ?? 'http://localhost:8000/api';
  const token = localStorage.getItem('sf_jwt');
  
  const response = await fetch(`${API_BASE}${endpoint}`, {
    method: 'POST',
    headers: { 
      'Content-Type': 'application/json',
      ...(token ? { 'Authorization': `Bearer ${token}` } : {})
    },
    body: JSON.stringify(payload)
  });
  
  if (!response.ok) {
    throw new Error(`API call failed: ${response.status}`);
  }
  
  return response.json();
};
// Direct API call - let individual components handle offline logic
export const postSync = async (endpoint: string, payload: any) => {
  const API_BASE = import.meta.env.VITE_TGTHR_API ?? 'https://outreachintake.aritasconsulting.com/api';
  const token = localStorage.getItem('sf_jwt');
  
  try {
    const resp = await fetch(`${API_BASE}${endpoint}`, {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        ...(token ? { 'Authorization': `Bearer ${token}` } : {})
      },
      body: JSON.stringify(payload)
    });

    if (!resp.ok) {
      const error = await resp.text().catch(() => 'Unknown error');
      throw new Error(`API call failed: ${resp.status} - ${error}`);
    }
    
    return resp.json();
  } catch (error) {
    if (error instanceof Error && error.message.includes('Failed to fetch')) {
      throw new Error('Unable to connect to the server. Please check your internet connection.');
    }
    throw error;
  }
};

export const getSync = async (endpoint: string) => {
  const API_BASE = import.meta.env.VITE_TGTHR_API ?? 'https://outreachintake.aritasconsulting.com/api';
  const token = localStorage.getItem('sf_jwt');
  
  try {
    const resp = await fetch(`${API_BASE}${endpoint}`, {
      method: 'GET',
      headers: { 
        ...(token ? { 'Authorization': `Bearer ${token}` } : {})
      }
    });

    if (!resp.ok) {
      const error = await resp.text().catch(() => 'Unknown error');
      throw new Error(`API call failed: ${resp.status} - ${error}`);
    }
    
    return resp.json();
  } catch (error) {
    if (error instanceof Error && error.message.includes('Failed to fetch')) {
      throw new Error('Unable to connect to the server. Please check your internet connection.');
    }
    throw error;
  }
};
// Placeholder for user auth
export const getCurrentUser = () => {
  return { id: 'user123', name: 'Current User' };
};

export const getOutreachUsers = async () => {
  return [{ id: 'user123', name: 'Current User', email: 'user@example.com' }];
};

export const setCurrentUser = (user: any) => {
  localStorage.setItem('currentUser', JSON.stringify(user));
};

export const testSalesforceConnection = async () => {
  return true;
};
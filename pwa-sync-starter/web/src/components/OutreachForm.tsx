// web/src/components/OutreachForm.tsx
import React, { useState } from 'react';
import { createPersonAccount, submitOutreachEncounter, getDeviceId } from '../lib/outreachApi';
import { isOnline, storeFormOffline } from '../lib/offlineStorage';
import type { PersonAccountPayload, OutreachEncounterPayload } from '../lib/outreachApi';

export function OutreachForm() {
  const [step, setStep] = useState<'person' | 'encounter'>('person');
  const [personId, setPersonId] = useState<string>('');
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');

  const [personData, setPersonData] = useState<PersonAccountPayload>({
    firstName: '',
    lastName: '',
    email: '',
    phone: '',
    birthdate: '',
    street: '',
    city: '',
    state: '',
    postalCode: '',
    genderIdentity: '',
    pronouns: ''
  });

  const [encounterData, setEncounterData] = useState<Omit<OutreachEncounterPayload, 'personLocalId' | 'deviceId'>>({
    encounterDate: new Date().toISOString().split('T')[0],
    location: '',
    notes: '',
    services: '',
    followUpNeeded: false
  });

  const handlePersonSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setMessage('');

    try {
      let result;
      
      if (isOnline()) {
        result = await createPersonAccount(personData);
      } else {
        result = await storeFormOffline('person', personData);
      }
      
      setPersonId(result.localId);
      setStep('encounter');
      setMessage(result.synced ? '✅ Person created and synced!' : '✅ Person saved offline (will sync when online)');
    } catch (error) {
      setMessage(`Error: ${error instanceof Error ? error.message : 'Unknown error'}`);
    } finally {
      setLoading(false);
    }
  };

  const handleEncounterSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setMessage('');

    try {
      const encounterPayload = {
        ...encounterData,
        personLocalId: personId,
        deviceId: getDeviceId()
      };
      
      if (isOnline()) {
        await submitOutreachEncounter(encounterPayload);
        setMessage('✅ Encounter recorded and synced!');
      } else {
        await storeFormOffline('encounter', encounterPayload);
        setMessage('✅ Encounter saved offline (will sync when online)');
      }
      
      // Reset form
      setStep('person');
      setPersonId('');
      setPersonData({
        firstName: '',
        lastName: '',
        email: '',
        phone: '',
        birthdate: '',
        street: '',
        city: '',
        state: '',
        postalCode: '',
        genderIdentity: '',
        pronouns: ''
      });
      setEncounterData({
        encounterDate: new Date().toISOString().split('T')[0],
        location: '',
        notes: '',
        services: '',
        followUpNeeded: false
      });
    } catch (error) {
      setMessage(`Error: ${error instanceof Error ? error.message : 'Unknown error'}`);
    } finally {
      setLoading(false);
    }
  };

  if (step === 'person') {
    return (
      <div className="max-w-md mx-auto p-6 bg-white rounded-lg shadow-md">
        <h2 className="text-2xl font-bold mb-4">New Person</h2>
        
        {message && (
          <div className={`p-3 mb-4 rounded ${message.includes('Error') ? 'bg-red-100 text-red-700' : 'bg-green-100 text-green-700'}`}>
            {message}
          </div>
        )}

        <form onSubmit={handlePersonSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">First Name *</label>
            <input
              type="text"
              required
              value={personData.firstName}
              onChange={(e) => setPersonData({...personData, firstName: e.target.value})}
              className="w-full p-2 border rounded"
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Last Name *</label>
            <input
              type="text"
              required
              value={personData.lastName}
              onChange={(e) => setPersonData({...personData, lastName: e.target.value})}
              className="w-full p-2 border rounded"
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Phone</label>
            <input
              type="tel"
              value={personData.phone}
              onChange={(e) => setPersonData({...personData, phone: e.target.value})}
              className="w-full p-2 border rounded"
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Email</label>
            <input
              type="email"
              value={personData.email}
              onChange={(e) => setPersonData({...personData, email: e.target.value})}
              className="w-full p-2 border rounded"
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-1">Birth Date</label>
            <input
              type="date"
              value={personData.birthdate}
              onChange={(e) => setPersonData({...personData, birthdate: e.target.value})}
              className="w-full p-2 border rounded"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-blue-600 text-white p-2 rounded hover:bg-blue-700 disabled:opacity-50"
          >
            {loading ? 'Creating...' : 'Create Person & Continue'}
          </button>
        </form>
      </div>
    );
  }

  return (
    <div className="max-w-md mx-auto p-6 bg-white rounded-lg shadow-md">
      <h2 className="text-2xl font-bold mb-4">Outreach Encounter</h2>
      
      {message && (
        <div className={`p-3 mb-4 rounded ${message.includes('Error') ? 'bg-red-100 text-red-700' : 'bg-green-100 text-green-700'}`}>
          {message}
        </div>
      )}

      <form onSubmit={handleEncounterSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium mb-1">Date *</label>
          <input
            type="date"
            required
            value={encounterData.encounterDate}
            onChange={(e) => setEncounterData({...encounterData, encounterDate: e.target.value})}
            className="w-full p-2 border rounded"
          />
        </div>

        <div>
          <label className="block text-sm font-medium mb-1">Location *</label>
          <input
            type="text"
            required
            placeholder="e.g., Downtown Park, 5th & Main"
            value={encounterData.location}
            onChange={(e) => setEncounterData({...encounterData, location: e.target.value})}
            className="w-full p-2 border rounded"
          />
        </div>

        <div>
          <label className="block text-sm font-medium mb-1">Notes *</label>
          <textarea
            required
            rows={4}
            placeholder="Describe the encounter, needs identified, etc."
            value={encounterData.notes}
            onChange={(e) => setEncounterData({...encounterData, notes: e.target.value})}
            className="w-full p-2 border rounded"
          />
        </div>

        <div>
          <label className="block text-sm font-medium mb-1">Services Provided</label>
          <input
            type="text"
            placeholder="e.g., Food, Information, Referral"
            value={encounterData.services}
            onChange={(e) => setEncounterData({...encounterData, services: e.target.value})}
            className="w-full p-2 border rounded"
          />
        </div>

        <div className="flex items-center">
          <input
            type="checkbox"
            id="followUp"
            checked={encounterData.followUpNeeded}
            onChange={(e) => setEncounterData({...encounterData, followUpNeeded: e.target.checked})}
            className="mr-2"
          />
          <label htmlFor="followUp" className="text-sm font-medium">Follow-up needed</label>
        </div>

        <div className="flex space-x-2">
          <button
            type="button"
            onClick={() => setStep('person')}
            className="flex-1 bg-gray-300 text-gray-700 p-2 rounded hover:bg-gray-400"
          >
            Back
          </button>
          <button
            type="submit"
            disabled={loading}
            className="flex-1 bg-green-600 text-white p-2 rounded hover:bg-green-700 disabled:opacity-50"
          >
            {loading ? 'Saving...' : 'Save Encounter'}
          </button>
        </div>
      </form>
    </div>
  );
}
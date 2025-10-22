import { useState } from 'react';
import { db } from '../../store/outreachStore';
import { submitOutreachEncounter } from '../../api/outreachApi';
import { newEncounterDefaults, type OutreachEncounter, type OutreachEncounterPayload } from '../../types/outreach';

export default function OutreachForm() {
  const [form, setForm] = useState<OutreachEncounter>(newEncounterDefaults());
  const [status, setStatus] = useState('');
  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    const record = newEncounterDefaults();
    const id = await db.encounters.add(record);
    setStatus('Saved locally');

    if (navigator.onLine) {
      try {
        const { id: _omit, synced: _omit2, ...payload } = record;
        const res = await submitOutreachEncounter(payload);
        if (res.ok) {
          await db.encounters.update(id!, { synced: true });
          setStatus('Synced to Salesforce ☁️');
        } else {
          setStatus(`Server rejected (${res.status}) — will retry`);
        }
      } catch (err) {
        console.error(err);
        setStatus('Network error — will retry later');
      }
    }
  }

  return (
    <form onSubmit={handleSubmit} className="p-4 space-y-3">
      <h1 className="text-xl font-bold">TGTHR Outreach Contact</h1>
      <input placeholder="First name" value={form.firstName}
             onChange={e => setForm({ ...form, firstName: e.target.value })}/>
      <input placeholder="Last name / alias" value={form.lastName}
             onChange={e => setForm({ ...form, lastName: e.target.value })}/>
      <label>Start Time</label>
      <input type="datetime-local" value={form.start.slice(0,16)}
             onChange={e => setForm({ ...form, start: e.target.value })}/>
      <label>End Time</label>
      <input type="datetime-local" value={form.end.slice(0,16)}
             onChange={e => setForm({ ...form, end: e.target.value })}/>
      <label>POS (default 27)</label>
      <input value={form.pos} onChange={e => setForm({ ...form, pos: e.target.value })}/>
      <label><input type="checkbox"
                    checked={form.isCrisis}
                    onChange={e => setForm({ ...form, isCrisis: e.target.checked })}/> Crisis Encounter</label>
      <textarea placeholder="Notes"
                value={form.notes}
                onChange={e => setForm({ ...form, notes: e.target.value })}/>
      <button type="submit" className="bg-blue-600 text-white px-4 py-2 rounded">Save Encounter</button>
      <div className="text-sm mt-2">{status}</div>
    </form>
  );
}

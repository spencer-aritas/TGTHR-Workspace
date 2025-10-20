// src/features/intake/ProgramIntakeForm.tsx
import React, { useState } from 'react'
import { NewClientIntakeForm, createIntakeDefaults } from '../../types/intake'
import { submitNewClientIntake } from '../../api/intakeApi'
import { intakeDb, StoredIntake } from '../../store/intakeStore'

export default function ProgramIntakeForm() {
  const [form, setForm] = useState<NewClientIntakeForm>(createIntakeDefaults())
  const [status, setStatus] = useState<string>('')
  const [issues, setIssues] = useState<string[]>([])
  const [isSubmitting, setIsSubmitting] = useState(false)

  const update = (k: keyof NewClientIntakeForm, v: any) => 
    setForm(f => ({ ...f, [k]: v }))

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (isSubmitting) return
    
    setIsSubmitting(true)
    setStatus('Creating new client intake...')
    setIssues([])
    
    try {
      // Store locally first
      const now = new Date().toISOString()
      const deviceId = localStorage.getItem('deviceId') || crypto.randomUUID()
      const userEmail = localStorage.getItem('userEmail') || 'unknown@tgthr.org'
      const userName = localStorage.getItem('userName') || 'Unknown User'
      
      const storedIntake: StoredIntake = {
        ...form,
        encounterUuid: crypto.randomUUID(),
        personUuid: crypto.randomUUID(),
        createdAt: now,
        synced: false
      }
      
      await intakeDb.intakes.add(storedIntake)
      
      // Try to sync
      const result = await submitNewClientIntake(form)
      if (result.success) {
        // Mark as synced
        await intakeDb.intakes.update(storedIntake.id!, { 
          synced: result.synced, 
          syncedAt: result.synced ? now : undefined 
        })
        setStatus(`Intake created successfully. ${result.synced ? 'Synced to Salesforce.' : 'Will sync when online.'}`)
        setForm(createIntakeDefaults())
      } else {
        await intakeDb.intakes.update(storedIntake.id!, { error: result.errors?.join(', ') })
        setIssues(result.errors || ['Unknown error occurred'])
        setStatus('')
      }
    } catch (error) {
      setIssues([error instanceof Error ? error.message : 'Network error'])
      setStatus('Saved locally. Will sync when online.')
      setForm(createIntakeDefaults())
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <form className="slds-form slds-p-around_medium" onSubmit={handleSubmit}>
      <div className="slds-form-element">
        <label className="slds-form-element__label">First Name *</label>
        <div className="slds-form-element__control">
          <input className="slds-input" value={form.firstName} 
            onChange={e=>update('firstName', e.target.value)} required/>
        </div>
      </div>
      
      <div className="slds-form-element slds-m-top_small">
        <label className="slds-form-element__label">Last Name *</label>
        <div className="slds-form-element__control">
          <input className="slds-input" value={form.lastName} 
            onChange={e=>update('lastName', e.target.value)} required/>
        </div>
      </div>
      
      <div className="slds-form-element slds-m-top_small">
        <label className="slds-form-element__label">Phone</label>
        <div className="slds-form-element__control">
          <input type="tel" className="slds-input" value={form.phone||''} 
            onChange={e=>update('phone', e.target.value)}/>
        </div>
      </div>
      
      <div className="slds-form-element slds-m-top_small">
        <label className="slds-form-element__label">Email</label>
        <div className="slds-form-element__control">
          <input type="email" className="slds-input" value={form.email||''} 
            onChange={e=>update('email', e.target.value)}/>
        </div>
      </div>
      
      <div className="slds-form-element slds-m-top_small">
        <label className="slds-form-element__label">Date of Birth</label>
        <div className="slds-form-element__control">
          <input type="date" className="slds-input" value={form.birthdate||''} 
            onChange={e=>update('birthdate', e.target.value)}/>
        </div>
      </div>
      
      <div className="slds-form-element slds-m-top_small">
        <label className="slds-form-element__label">Interaction Notes</label>
        <div className="slds-form-element__control">
          <textarea className="slds-textarea" rows={4} value={form.notes} 
            onChange={e=>update('notes', e.target.value)}/>
        </div>
      </div>

      {issues.length > 0 && (
        <div className="slds-text-color_error slds-m-top_small">
          {issues.map((m,i)=><div key={i}>• {m}</div>)}
        </div>
      )}

      <div className="slds-m-top_medium">
        <button className="slds-button slds-button_brand" type="submit" disabled={isSubmitting}>
          {isSubmitting ? 'Creating Intake...' : 'Create New Client Intake'}
        </button>
        <span className="slds-m-left_small">{status}</span>
      </div>
    </form>
  )
}

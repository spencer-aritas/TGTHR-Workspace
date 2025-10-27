// src/features/intake/ProgramIntakeForm.tsx
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { IntakeLocation, NewClientIntakeForm, createIntakeDefaults } from '../../types/intake'
import { submitNewClientIntake } from '../../api/intakeApi'
import { intakeDb, StoredIntake } from '../../store/intakeStore'

type PermissionStateExtended = PermissionState | 'unsupported' | 'unknown'

export default function ProgramIntakeForm() {
  const [form, setForm] = useState<NewClientIntakeForm>(createIntakeDefaults())
  const [status, setStatus] = useState<string>('')
  const [issues, setIssues] = useState<string[]>([])
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [locationStatus, setLocationStatus] = useState<string>('Capturing device location...')
  const [locationPermission, setLocationPermission] = useState<PermissionStateExtended>('unknown')
  const isMountedRef = useRef(true)
  const lastLocationRef = useRef<IntakeLocation | undefined>(undefined)
  const lastLocationKey = useMemo(() => 'tgthr_last_intake_location', [])

  const update = (k: keyof NewClientIntakeForm, v: any) => 
    setForm(f => ({ ...f, [k]: v }))

  const persistLocation = useCallback((location: IntakeLocation) => {
    lastLocationRef.current = location
    try {
      localStorage.setItem(lastLocationKey, JSON.stringify(location))
    } catch (err) {
      console.warn('Failed to persist last location', err)
    }
  }, [lastLocationKey])

  const loadLastLocation = useCallback((): IntakeLocation | undefined => {
    try {
      const cached = localStorage.getItem(lastLocationKey)
      if (!cached) return undefined
      const parsed = JSON.parse(cached) as IntakeLocation
      lastLocationRef.current = parsed
      return parsed
    } catch (err) {
      console.warn('Failed to load cached location', err)
      return undefined
    }
  }, [lastLocationKey])

  const buildLocation = useCallback((position: GeolocationPosition): IntakeLocation => {
    const { coords, timestamp } = position
    return {
      latitude: coords.latitude,
      longitude: coords.longitude,
      accuracy: Number.isFinite(coords.accuracy) ? coords.accuracy : null,
      altitude: coords.altitude ?? null,
      heading: coords.heading ?? null,
      speed: coords.speed ?? null,
      timestamp: new Date(timestamp || Date.now()).toISOString(),
      source: 'device'
    }
  }, [])

  const captureLocation = useCallback(async (): Promise<IntakeLocation | undefined> => {
    if (typeof window === 'undefined' || !('geolocation' in navigator)) {
      if (isMountedRef.current) {
        setLocationStatus('Geolocation is not supported on this device.')
        setForm(f => ({ ...f, location: undefined }))
      }
      return undefined
    }

    setLocationStatus('Capturing device location...')

    const location = await new Promise<IntakeLocation | undefined>((resolve) => {
      navigator.geolocation.getCurrentPosition(
        position => {
          const nextLocation = buildLocation(position)
          if (isMountedRef.current) {
            setForm(f => ({ ...f, location: nextLocation }))
            const accuracyText = nextLocation.accuracy != null ? `±${Math.round(nextLocation.accuracy)}m` : 'accuracy unknown'
            setLocationStatus(`Location captured (${accuracyText}).`)
            persistLocation(nextLocation)
          }
          resolve(nextLocation)
        },
        error => {
          if (!isMountedRef.current) {
            resolve(undefined)
            return
          }

          let message = 'Unable to capture device location.'
          switch (error.code) {
            case error.PERMISSION_DENIED:
              message = 'Location permission denied. Enable location services to include intake location.'
              break
            case error.POSITION_UNAVAILABLE:
              message = 'Location unavailable. Move to an open area or try again.'
              break
            case error.TIMEOUT:
              message = 'Location request timed out. Try again or check device settings.'
              break
            default:
              message = `Location error: ${error.message || 'unknown error.'}`
          }
          setLocationStatus(message)
          if (lastLocationRef.current) {
            const fallbackTime = new Date(lastLocationRef.current.timestamp).toLocaleString()
            setLocationStatus(prev => `${message} Using last known location captured ${fallbackTime}.`)
            resolve(lastLocationRef.current)
            return
          }
          resolve(undefined)
        },
        {
          enableHighAccuracy: true,
          timeout: 20000,
          maximumAge: 0
        }
      )
    })

    return location
  }, [buildLocation])

  useEffect(() => {
    let permissionStatus: PermissionStatus | undefined

    const cachedLocation = loadLastLocation()
    if (cachedLocation && !form.location) {
      setForm(current => ({ ...current, location: cachedLocation }))
      setLocationStatus(`Using last known location captured ${new Date(cachedLocation.timestamp).toLocaleString()}.`)
    }

    if (typeof navigator !== 'undefined' && navigator.permissions?.query) {
      navigator.permissions.query({ name: 'geolocation' as PermissionName })
        .then(status => {
          if (!isMountedRef.current) return
          permissionStatus = status
          setLocationPermission(status.state)
          status.onchange = () => {
            if (isMountedRef.current) {
              setLocationPermission(status.state)
            }
          }
          if (status.state === 'granted' || status.state === 'prompt') {
            captureLocation()
          } else {
            setLocationStatus('Location access is blocked. Enable permissions to capture device location, otherwise submissions will proceed without coordinates.')
          }
        })
        .catch(() => {
          if (!isMountedRef.current) return
          setLocationPermission('unknown')
          captureLocation()
        })
    } else {
      setLocationPermission('unsupported')
      captureLocation()
    }

    return () => {
      if (permissionStatus) {
        permissionStatus.onchange = null
      }
    }
  }, [captureLocation])

  useEffect(() => {
    return () => {
      isMountedRef.current = false
    }
  }, [])

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (isSubmitting) return
    
    setIsSubmitting(true)
    setStatus('Creating new client intake...')
    setIssues([])
    let storedIntakeId: number | undefined
    let savedLocally = false

    try {
      // Store locally first
      const now = new Date().toISOString()
      const deviceId = localStorage.getItem('deviceId') || crypto.randomUUID()
      const userEmail = localStorage.getItem('userEmail') || 'unknown@tgthr.org'
      const userName = localStorage.getItem('userName') || 'Unknown User'

      let ensuredLocation = form.location ?? await captureLocation()
      if (!ensuredLocation) {
        ensuredLocation = lastLocationRef.current
        if (ensuredLocation) {
          setLocationStatus(`Using last known location captured ${new Date(ensuredLocation.timestamp).toLocaleString()}.`)
        } else {
          setLocationStatus('No device location available. Saving intake without coordinates.')
        }
      }

      const submissionForm: NewClientIntakeForm = {
        ...form,
        location: ensuredLocation
      }
      
      const storedIntake: StoredIntake = {
        ...submissionForm,
        encounterUuid: crypto.randomUUID(),
        personUuid: crypto.randomUUID(),
        createdAt: now,
        synced: false
      }
      storedIntakeId = await intakeDb.intakes.add(storedIntake)
      savedLocally = true
      storedIntake.id = storedIntakeId
      
      // Try to sync
      const result = await submitNewClientIntake(submissionForm)
      if (result.success) {
        // Mark as synced
        if (storedIntakeId !== undefined) {
          await intakeDb.intakes.update(storedIntakeId, { 
          synced: result.synced, 
          syncedAt: result.synced ? now : undefined 
        })
        }
        setStatus(`Intake created successfully. ${result.synced ? 'Synced to Salesforce.' : 'Will sync when online.'}`)
        setForm(createIntakeDefaults())
        void captureLocation()
      } else {
        if (storedIntakeId !== undefined) {
          await intakeDb.intakes.update(storedIntakeId, { error: result.errors?.join(', ') })
        }
        setIssues(result.errors || ['Unknown error occurred'])
        setStatus('')
      }
    } catch (error) {
      console.error('Intake submission failed', error)
      if (savedLocally && storedIntakeId !== undefined) {
        const message = error instanceof Error ? error.message : 'Network error'
        await intakeDb.intakes.update(storedIntakeId, { error: message, synced: false })
        setIssues([])
        setStatus('Saved locally. Will sync when online.')
        setForm(createIntakeDefaults())
        void captureLocation()
      } else {
        setIssues([error instanceof Error ? error.message : 'Unable to save intake'])
        setStatus('Save failed. Please try again.')
      }
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

      <div className="slds-form-element slds-m-top_small">
        <label className="slds-form-element__label">Device Location</label>
        <div className="slds-form-element__control">
          <div className="slds-text-body_small">
            {form.location
              ? `Lat ${form.location.latitude.toFixed(5)}, Lon ${form.location.longitude.toFixed(5)}${form.location.accuracy != null ? ` (±${Math.round(form.location.accuracy)}m)` : ''}`
              : 'No location captured yet.'}
          </div>
          <div className="slds-text-color_weak slds-text-body_small slds-m-top_xx-small">
            {locationStatus}
          </div>
          {locationPermission === 'denied' && (
            <div className="slds-text-color_error slds-text-body_small slds-m-top_xx-small">
              Location access is currently blocked. Enable location permissions in your browser or device settings and tap “Refresh Location” to include coordinates, or continue without them.
            </div>
          )}
          <button
            type="button"
            className="slds-button slds-button_neutral slds-m-top_xx-small"
            onClick={() => { void captureLocation() }}
            disabled={isSubmitting}
          >
            {form.location ? 'Refresh Location' : 'Enable Location'}
          </button>
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

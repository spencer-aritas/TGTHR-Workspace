import React, { useState, type FormEvent } from "react";
// Using crypto.randomUUID instead of uuid package
const uuid = () => crypto.randomUUID();
import { postSync } from "../../lib/api";
import { getCurrentUser, getDeviceId } from "../../lib/salesforceAuth";

type Person = {
  firstName: string;
  lastName: string;
  email?: string;
  phone?: string;
  birthdate?: string;
  street?: string;
  city?: string;
  state?: string;
  postalCode?: string;
  ssnLast4?: string;
  hmisId?: string;
  alternateEmail?: string;
  genderIdentity?: string;
  eyeColor?: string;
  hairDescription?: string;
  height?: string;
  weight?: string;
  preferredLanguage?: string;
  translatorNeeded?: boolean;
  notableFeatures?: string;
  genderIdentityOther?: string;
  pronouns?: string;
  pronounsOther?: string;
  raceEthnicity?: string;
  veteranService?: string;
  notes?: string;
};

const GENDER_OPTIONS = [
  "Man (Boy, if child)",
  "Woman (Girl, if child)",
  "Non-Binary",
  "Cultural Specific Identity (e.g., Two  Spirit)",
  "Questioning",
  "Different Identity",
  "Doesn't Know",
  "Prefers Not to Answer",
  "Data Not Collected",
];

const SF = import.meta.env.VITE_SF_LIGHTNING_DOMAIN as string | undefined;

export default function PersonForm() {
  const [form, setForm] = useState<Partial<Person>>({});
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string>("");
  const [sfId, setSfId] = useState<string | null>(null);
  const [errs, setErrs] = useState<string[]>([]);

  const update = React.useCallback(<K extends keyof Person>(k: K, v: Person[K]) => {
    setForm((prev) => ({ ...prev, [k]: v }));
  }, []);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    e.stopPropagation();
    
    if (!navigator.onLine) {
      // Offline - do nothing to avoid any state changes
      setMsg("📱 Offline - form saved locally");
      return false;
    }
    
    setErrs([]);
    setMsg("");
    setSfId(null);

    // Validate first
    const issues: string[] = [];
    if (!form.firstName?.trim()) issues.push("First name is required");
    if (!form.lastName?.trim()) issues.push("Last name is required");
    if (issues.length) {
      setErrs(issues);
      return;
    }

    // Build payload with user info
    const user = getCurrentUser();
    const payload = { 
      localId: uuid(), 
      person: {
        ...form,
        createdBy: user?.name || 'Unknown',
        createdByEmail: user?.email || '',
        deviceId: getDeviceId()
      }
    };

    setBusy(true);
    try {
      const result = await postSync("/sync/PersonAccount", payload);

      if ("queued" in result) {
        setMsg("Saved (queued to sync)");
      } else {
        setMsg("Saved");
        if ((result as any).salesforceId) setSfId((result as any).salesforceId);
      }
      setForm({});
    } catch (err: any) {
      setErrs([String(err?.message || err)]);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="slds-m-bottom_large">

      
      <form className="slds-form" onSubmit={onSubmit}>
        <div className="slds-form-element slds-m-bottom_medium">
          <label className="slds-form-element__label slds-text-body_regular" htmlFor="firstName">
            <span className="slds-text-color_error">*</span> First Name
          </label>
          <div className="slds-form-element__control">
            <input
              id="firstName"
              className="slds-input slds-input_bare"
              style={{fontSize: '16px', padding: '12px 16px', borderRadius: '8px', border: '2px solid #e5e5e5'}}
              type="text"
              placeholder="Enter first name"
              value={form.firstName || ""}
              onChange={(e) => update("firstName", e.target.value)}
              autoComplete="given-name"
              inputMode="text"
            />
          </div>
        </div>
        
        <div className="slds-form-element slds-m-bottom_medium">
          <label className="slds-form-element__label slds-text-body_regular" htmlFor="lastName">
            <span className="slds-text-color_error">*</span> Last Name
          </label>
          <div className="slds-form-element__control">
            <input
              id="lastName"
              className="slds-input slds-input_bare"
              style={{fontSize: '16px', padding: '12px 16px', borderRadius: '8px', border: '2px solid #e5e5e5'}}
              type="text"
              placeholder="Enter last name"
              value={form.lastName || ""}
              onChange={(e) => update("lastName", e.target.value)}
              autoComplete="family-name"
              inputMode="text"
            />
          </div>
        </div>
        
        <div className="slds-form-element slds-m-bottom_medium">
          <label className="slds-form-element__label slds-text-body_regular" htmlFor="phone">Phone</label>
          <div className="slds-form-element__control">
            <input
              id="phone"
              className="slds-input slds-input_bare"
              style={{fontSize: '16px', padding: '12px 16px', borderRadius: '8px', border: '2px solid #e5e5e5'}}
              type="tel"
              placeholder="(555) 123-4567"
              value={form.phone || ""}
              onChange={(e) => update("phone", e.target.value)}
              autoComplete="tel"
              inputMode="tel"
            />
          </div>
        </div>
        
        <div className="slds-form-element slds-m-bottom_medium">
          <label className="slds-form-element__label slds-text-body_regular" htmlFor="email">Email</label>
          <div className="slds-form-element__control">
            <input
              id="email"
              className="slds-input slds-input_bare"
              style={{fontSize: '16px', padding: '12px 16px', borderRadius: '8px', border: '2px solid #e5e5e5'}}
              type="email"
              placeholder="email@example.com"
              value={form.email || ""}
              onChange={(e) => update("email", e.target.value)}
              autoComplete="email"
              inputMode="email"
            />
          </div>
        </div>
        
        <div className="slds-form-element slds-m-bottom_medium">
          <label className="slds-form-element__label slds-text-body_regular" htmlFor="birthdate">Birth Date</label>
          <div className="slds-form-element__control">
            <input
              id="birthdate"
              className="slds-input slds-input_bare"
              style={{fontSize: '16px', padding: '12px 16px', borderRadius: '8px', border: '2px solid #e5e5e5'}}
              type="date"
              value={form.birthdate || ""}
              onChange={(e) => update("birthdate", e.target.value)}
            />
          </div>
        </div>
        
        <div className="slds-form-element slds-m-bottom_large">
          <label className="slds-form-element__label slds-text-body_regular" htmlFor="notes">Interaction Notes</label>
          <div className="slds-form-element__control">
            <textarea
              id="notes"
              className="slds-textarea"
              style={{fontSize: '16px', padding: '12px 16px', borderRadius: '8px', border: '2px solid #e5e5e5', minHeight: '100px'}}
              placeholder="Describe the encounter, needs identified, services provided..."
              value={form.notes || ""}
              onChange={(e) => update("notes", e.target.value)}
            />
          </div>
        </div>

        {errs.length > 0 && (
          <div className="slds-text-color_error slds-m-top_small">
            {errs.map((e, i) => (
              <div key={i}>• {e}</div>
            ))}
          </div>
        )}

        {sfId && SF && (
          <div className="slds-m-top_small">
            <a className="slds-button slds-button_neutral" href={`${SF}/lightning/r/Account/${sfId}/view`} target="_blank">
              Open in Salesforce
            </a>
          </div>
        )}

        <div className="slds-m-top_large">
          <button 
            className="slds-button slds-button_brand" 
            style={{
              width: '100%', 
              padding: '16px', 
              fontSize: '18px', 
              fontWeight: 'bold',
              borderRadius: '12px',
              backgroundColor: '#1976d2',
              border: 'none',
              boxShadow: '0 4px 12px rgba(25, 118, 210, 0.3)'
            }}
            type="submit" 
            disabled={busy}
          >
            {busy ? "Creating Client..." : "🤝 Add New Client"}
          </button>
          {msg && (
          <span className={`slds-m-left_small ${
            msg.includes('queued') ? 'slds-text-color_warning' : 'slds-text-color_success'
          }`}>
            {msg.includes('queued') ? '⏳' : '✅'} {msg}
          </span>
        )}
          {sfId && (
            <div className="slds-m-top_small">
              <span className="slds-badge slds-theme_success">☁️ Synced to Salesforce</span>
            </div>
          )}
        </div>
      </form>
    </div>
  );
}

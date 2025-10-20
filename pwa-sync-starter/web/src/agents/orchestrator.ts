// src/agents/orchestrator.ts
/**
 * Lightweight multi-agent scaffolding:
 * - schemaAgent: validate/normalize forms to domain schema
 * - policyAgent: apply client-side rules (e.g., age checks, required consents)
 * - syncAgent: enqueue to outbox
 */
import { enqueue } from '../lib/sync'

type Result<T> = { ok: true, value: T } | { ok: false, issues: string[] }

export const schemaAgent = {
  person(input: any): Result<any> {
    const issues: string[] = []
    if (!input.firstName) issues.push('First name is required')
    if (!input.lastName) issues.push('Last name is required')
    const out = {
      id: crypto.randomUUID(),
      firstName: String(input.firstName || '').trim(),
      lastName: String(input.lastName || '').trim(),
      email: input.email?.trim() || undefined,
      phone: input.phone?.trim() || undefined,
      birthdate: input.birthdate || undefined,
      street: input.street || undefined,
      city: input.city || undefined,
      state: input.state || undefined,
      postalCode: input.postalCode || undefined,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      _status: 'pending'
    }
    return issues.length ? { ok: false, issues } : { ok: true, value: out }
  },
  intake(input: any): Result<any> {
    const issues: string[] = []
    if (!input.personLocalId) issues.push('Person reference missing')
    if (!input.programId) issues.push('Program is required')
    const out = {
      id: crypto.randomUUID(),
      personLocalId: input.personLocalId,
      programId: input.programId,
      startDate: input.startDate || new Date().toISOString().slice(0,10),
      consentSigned: !!input.consentSigned,
      notes: input.notes || undefined,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      _status: 'pending'
    }
    return issues.length ? { ok: false, issues } : { ok: true, value: out }
  }
}

export const policyAgent = {
  checkMinor(birthdate?: string): boolean {
    if (!birthdate) return false
    const b = new Date(birthdate)
    const age = (Date.now() - b.getTime()) / (365.25*24*3600*1000)
    return age < 18
  },
  intakeGuards(intake: any, person: any): string[] {
    const issues: string[] = []
    if (this.checkMinor(person.birthdate) && !intake.consentSigned) {
      issues.push('Guardian/consent required for minors.')
    }
    return issues
  }
}

export const syncAgent = {
  async submitPerson(person: any) {
    await enqueue('PersonAccount', { localId: person.id, person })
  },
  async submitIntake(intake: any) {
    await enqueue('ProgramIntake', { localId: intake.id, intake })
  }
}

export const Orchestrator = {
  async createPerson(input: any) {
    const parsed = schemaAgent.person(input)
    if (!parsed.ok) return parsed
    await syncAgent.submitPerson(parsed.value)
    return parsed
  },
  async createIntake(input: any, person: any) {
    const parsed = schemaAgent.intake(input)
    if (!parsed.ok) return parsed
    const policyIssues = policyAgent.intakeGuards(parsed.value, person)
    if (policyIssues.length) return { ok: false, issues: policyIssues }
    await syncAgent.submitIntake(parsed.value)
    return parsed
  }
}

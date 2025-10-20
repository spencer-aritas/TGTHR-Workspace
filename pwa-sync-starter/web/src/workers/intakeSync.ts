// web/src/workers/intakeSync.ts
import { intakeDb } from '../store/intakeStore';
import { submitNewClientIntake } from '../api/intakeApi';

export async function syncPendingIntakes(): Promise<void> {
  const pending = await intakeDb.intakes.where('synced').equals(false).toArray();
  
  for (const intake of pending) {
    try {
      const result = await submitNewClientIntake(intake);
      if (result.success && result.synced) {
        await intakeDb.intakes.update(intake.id!, { 
          synced: true, 
          syncedAt: new Date().toISOString(),
          error: undefined 
        });
      } else {
        await intakeDb.intakes.update(intake.id!, { 
          error: result.errors?.join(', ') || 'Sync failed' 
        });
      }
    } catch (error) {
      await intakeDb.intakes.update(intake.id!, { 
        error: error instanceof Error ? error.message : 'Network error' 
      });
    }
  }
}
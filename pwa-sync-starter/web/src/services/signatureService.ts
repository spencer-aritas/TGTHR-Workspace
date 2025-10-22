interface SignatureData {
  dataURL: string;
  timestamp: string;
  recordId?: string;
  recordType?: string;
}

interface SignatureRecord {
  id?: string;
  dataURL: string;
  timestamp: string;
  recordId?: string;
  recordType?: string;
  synced: boolean;
}

class SignatureService {
  async saveSignature(signatureData: SignatureData): Promise<string> {
    const record: SignatureRecord = {
      ...signatureData,
      synced: false
    };

    // Save to IndexedDB
    const { db } = await import('../lib/db');
    const id = await db.signatures.add(record);
    
    // Queue for sync
    await this.queueForSync(String(id), record);
    
    return String(id);
  }

  private async queueForSync(id: string, record: SignatureRecord) {
    const { db } = await import('../lib/db');
    await db.outbox.add({
      entity: 'SignatureRecord',
      payload: { id, ...record },
      createdAt: new Date().toISOString(),
      attempts: 0
    });
  }

  async uploadToSalesforce(signatureData: SignatureRecord): Promise<void> {
    const formData = new FormData();
    
    // Convert dataURL to blob
    const response = await fetch(signatureData.dataURL);
    const blob = await response.blob();
    
    formData.append('file', blob, `signature_${signatureData.timestamp}.png`);
    formData.append('recordId', signatureData.recordId || '');
    formData.append('recordType', signatureData.recordType || '');
    formData.append('timestamp', signatureData.timestamp);

    const result = await fetch('/api/signatures/upload', {
      method: 'POST',
      body: formData
    });

    if (!result.ok) {
      throw new Error('Failed to upload signature');
    }
  }
}

export const signatureService = new SignatureService();
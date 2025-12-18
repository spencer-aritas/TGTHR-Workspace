// Photo service for PWA - handles upload and retrieval of client photos
import { getApiUrl } from '../lib/api';

export interface PhotoUploadRequest {
  dataURL: string;      // Base64 encoded image data
  accountId: string;    // Salesforce Account ID
  timestamp: string;    // ISO timestamp
  width?: number;
  height?: number;
}

export interface PhotoUploadResponse {
  success: boolean;
  contentDocumentId?: string;
  photoUrl?: string;
  message: string;
}

export interface AccountPhotoInfo {
  accountId: string;
  photoUrl: string | null;
  knownAllergies: string | null;
  currentMedications: string | null;
  medicationNotes: string | null;
}

/**
 * Upload a photo for an Account (Person Account)
 * The photo is stored as a ContentVersion linked to the Account
 * and the Account's Photo__pc field is updated
 */
export async function uploadAccountPhoto(
  request: PhotoUploadRequest
): Promise<PhotoUploadResponse> {
  const apiUrl = getApiUrl();
  
  try {
    const response = await fetch(`${apiUrl}/photos/upload`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        accountId: request.accountId,
        imageData: request.dataURL,
        timestamp: request.timestamp,
        width: request.width,
        height: request.height,
      }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.detail || `Upload failed: ${response.status}`);
    }

    return await response.json();
  } catch (error) {
    console.error('Photo upload error:', error);
    throw error;
  }
}

/**
 * Get photo and emergency info for an Account
 * Returns photo URL, allergies, and medication info
 */
export async function getAccountPhotoAndEmergencyInfo(
  accountId: string
): Promise<AccountPhotoInfo> {
  const apiUrl = getApiUrl();
  
  try {
    const response = await fetch(`${apiUrl}/photos/account/${accountId}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.detail || `Fetch failed: ${response.status}`);
    }

    return await response.json();
  } catch (error) {
    console.error('Get account photo error:', error);
    // Return empty data on error rather than throwing
    return {
      accountId,
      photoUrl: null,
      knownAllergies: null,
      currentMedications: null,
      medicationNotes: null,
    };
  }
}

/**
 * Convert a base64 data URL to a Blob for form upload
 */
export function dataURLToBlob(dataURL: string): Blob {
  const parts = dataURL.split(',');
  const mime = parts[0].match(/:(.*?);/)?.[1] || 'image/jpeg';
  const bstr = atob(parts[1]);
  let n = bstr.length;
  const u8arr = new Uint8Array(n);
  
  while (n--) {
    u8arr[n] = bstr.charCodeAt(n);
  }
  
  return new Blob([u8arr], { type: mime });
}

/**
 * Resize an image data URL to fit within max dimensions
 */
export async function resizeImage(
  dataURL: string,
  maxWidth: number = 800,
  maxHeight: number = 800,
  quality: number = 0.9
): Promise<string> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => {
      let { width, height } = img;
      
      // Calculate scaling
      if (width > maxWidth || height > maxHeight) {
        const scale = Math.min(maxWidth / width, maxHeight / height);
        width = Math.round(width * scale);
        height = Math.round(height * scale);
      }

      // Create canvas and draw resized image
      const canvas = document.createElement('canvas');
      canvas.width = width;
      canvas.height = height;
      
      const ctx = canvas.getContext('2d');
      if (!ctx) {
        reject(new Error('Could not get canvas context'));
        return;
      }

      ctx.drawImage(img, 0, 0, width, height);
      resolve(canvas.toDataURL('image/jpeg', quality));
    };
    
    img.onerror = () => reject(new Error('Failed to load image'));
    img.src = dataURL;
  });
}

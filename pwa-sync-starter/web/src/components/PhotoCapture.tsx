import React, { useRef, useState, useCallback, useEffect } from 'react';

export interface PhotoCaptureProps {
  onCapture: (photoData: PhotoData) => void;
  onCancel?: () => void;
  recordId?: string;
  recordType?: string;
  maxWidth?: number;
  maxHeight?: number;
}

export interface PhotoData {
  dataURL: string;
  timestamp: string;
  recordId?: string;
  recordType?: string;
  width: number;
  height: number;
}

type CaptureMode = 'camera' | 'preview' | 'edit';

export const PhotoCapture: React.FC<PhotoCaptureProps> = ({
  onCapture,
  onCancel,
  recordId,
  recordType,
  maxWidth = 800,
  maxHeight = 800,
}) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const editCanvasRef = useRef<HTMLCanvasElement>(null);
  const streamRef = useRef<MediaStream | null>(null);

  const [mode, setMode] = useState<CaptureMode>('camera');
  const [capturedImage, setCapturedImage] = useState<string | null>(null);
  const [rotation, setRotation] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [cameraReady, setCameraReady] = useState(false);
  const [facingMode, setFacingMode] = useState<'user' | 'environment'>('environment');

  // Start camera
  const startCamera = useCallback(async () => {
    try {
      setError(null);
      setCameraReady(false);

      // Stop any existing stream
      if (streamRef.current) {
        streamRef.current.getTracks().forEach(track => track.stop());
      }

      const constraints: MediaStreamConstraints = {
        video: {
          facingMode: facingMode,
          width: { ideal: maxWidth },
          height: { ideal: maxHeight },
        },
        audio: false,
      };

      const stream = await navigator.mediaDevices.getUserMedia(constraints);
      streamRef.current = stream;

      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        videoRef.current.onloadedmetadata = () => {
          videoRef.current?.play();
          setCameraReady(true);
        };
      }
    } catch (err) {
      console.error('Camera access error:', err);
      if (err instanceof Error) {
        if (err.name === 'NotAllowedError') {
          setError('Camera access denied. Please allow camera permissions.');
        } else if (err.name === 'NotFoundError') {
          setError('No camera found on this device.');
        } else {
          setError(`Camera error: ${err.message}`);
        }
      } else {
        setError('Failed to access camera.');
      }
    }
  }, [facingMode, maxWidth, maxHeight]);

  // Stop camera
  const stopCamera = useCallback(() => {
    if (streamRef.current) {
      streamRef.current.getTracks().forEach(track => track.stop());
      streamRef.current = null;
    }
    setCameraReady(false);
  }, []);

  // Initialize camera on mount
  useEffect(() => {
    if (mode === 'camera') {
      startCamera();
    }
    return () => stopCamera();
  }, [mode, startCamera, stopCamera]);

  // Switch camera (front/back)
  const switchCamera = () => {
    setFacingMode(prev => (prev === 'user' ? 'environment' : 'user'));
  };

  // Capture photo from video stream
  const capturePhoto = () => {
    if (!videoRef.current || !canvasRef.current) return;

    const video = videoRef.current;
    const canvas = canvasRef.current;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Set canvas dimensions to match video
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;

    // Draw video frame to canvas
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

    // Get data URL
    const dataURL = canvas.toDataURL('image/jpeg', 0.9);
    setCapturedImage(dataURL);
    setRotation(0);
    setMode('preview');
    stopCamera();
  };

  // Rotate image
  const rotateImage = (degrees: number) => {
    setRotation((prev) => (prev + degrees) % 360);
  };

  // Apply edits and get final image
  const applyEdits = useCallback((): string | null => {
    if (!capturedImage || !editCanvasRef.current) return null;

    const canvas = editCanvasRef.current;
    const ctx = canvas.getContext('2d');
    if (!ctx) return null;

    const img = new Image();
    img.src = capturedImage;

    // Calculate rotated dimensions
    const isRotated90 = rotation === 90 || rotation === 270;
    const width = isRotated90 ? img.height : img.width;
    const height = isRotated90 ? img.width : img.height;

    // Scale down if needed
    let finalWidth = width;
    let finalHeight = height;
    if (width > maxWidth || height > maxHeight) {
      const scale = Math.min(maxWidth / width, maxHeight / height);
      finalWidth = width * scale;
      finalHeight = height * scale;
    }

    canvas.width = finalWidth;
    canvas.height = finalHeight;

    // Clear and apply transformations
    ctx.clearRect(0, 0, finalWidth, finalHeight);
    ctx.save();

    // Move to center, rotate, then draw
    ctx.translate(finalWidth / 2, finalHeight / 2);
    ctx.rotate((rotation * Math.PI) / 180);

    // Draw image centered
    const drawWidth = isRotated90 ? finalHeight : finalWidth;
    const drawHeight = isRotated90 ? finalWidth : finalHeight;
    ctx.drawImage(img, -drawWidth / 2, -drawHeight / 2, drawWidth, drawHeight);

    ctx.restore();

    return canvas.toDataURL('image/jpeg', 0.9);
  }, [capturedImage, rotation, maxWidth, maxHeight]);

  // Save the photo
  const handleSave = () => {
    // Need to load image first to get dimensions
    if (!capturedImage) return;

    const img = new Image();
    img.onload = () => {
      const editedDataURL = applyEdits();
      if (!editedDataURL) return;

      // Get final dimensions
      const isRotated90 = rotation === 90 || rotation === 270;
      let width = isRotated90 ? img.height : img.width;
      let height = isRotated90 ? img.width : img.height;
      if (width > maxWidth || height > maxHeight) {
        const scale = Math.min(maxWidth / width, maxHeight / height);
        width = width * scale;
        height = height * scale;
      }

      const photoData: PhotoData = {
        dataURL: editedDataURL,
        timestamp: new Date().toISOString(),
        recordId,
        recordType,
        width: Math.round(width),
        height: Math.round(height),
      };

      onCapture(photoData);
    };
    img.src = capturedImage;
  };

  // Retake photo
  const handleRetake = () => {
    setCapturedImage(null);
    setRotation(0);
    setMode('camera');
  };

  // Handle file input (for desktop or fallback)
  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      const dataURL = event.target?.result as string;
      setCapturedImage(dataURL);
      setRotation(0);
      setMode('preview');
    };
    reader.readAsDataURL(file);
  };

  return (
    <div className="photo-capture slds-p-around_medium">
      {/* Hidden canvases for processing */}
      <canvas ref={canvasRef} style={{ display: 'none' }} />
      <canvas ref={editCanvasRef} style={{ display: 'none' }} />

      {error && (
        <div className="slds-notify slds-notify_alert slds-alert_error slds-m-bottom_medium" role="alert">
          <span className="slds-assistive-text">Error</span>
          <span className="slds-icon_container slds-icon-utility-error slds-m-right_x-small">
            <svg className="slds-icon slds-icon_x-small" aria-hidden="true">
              <use xlinkHref="/assets/icons/utility-sprite/svg/symbols.svg#error"></use>
            </svg>
          </span>
          <h2>{error}</h2>
        </div>
      )}

      {mode === 'camera' && (
        <div className="camera-view">
          <div 
            className="video-container slds-m-bottom_medium"
            style={{
              position: 'relative',
              width: '100%',
              maxWidth: '500px',
              margin: '0 auto',
              backgroundColor: '#1a1a1a',
              borderRadius: '8px',
              overflow: 'hidden',
            }}
          >
            <video
              ref={videoRef}
              autoPlay
              playsInline
              muted
              style={{
                width: '100%',
                height: 'auto',
                display: cameraReady ? 'block' : 'none',
              }}
            />
            {!cameraReady && !error && (
              <div 
                className="slds-align_absolute-center"
                style={{ height: '300px', color: '#fff' }}
              >
                <div className="slds-spinner slds-spinner_medium" role="status">
                  <span className="slds-assistive-text">Loading camera...</span>
                  <div className="slds-spinner__dot-a"></div>
                  <div className="slds-spinner__dot-b"></div>
                </div>
              </div>
            )}
          </div>

          <div className="camera-controls slds-grid slds-grid_align-center slds-grid_vertical-align-center slds-gutters">
            {/* File input fallback */}
            <div className="slds-col slds-size_1-of-3 slds-text-align_left">
              <label className="slds-button slds-button_neutral">
                <input
                  type="file"
                  accept="image/*"
                  capture="environment"
                  onChange={handleFileSelect}
                  style={{ display: 'none' }}
                />
                <svg className="slds-button__icon slds-button__icon_left" aria-hidden="true">
                  <use xlinkHref="/assets/icons/utility-sprite/svg/symbols.svg#upload"></use>
                </svg>
                Upload
              </label>
            </div>

            {/* Capture button */}
            <div className="slds-col slds-size_1-of-3 slds-text-align_center">
              <button
                type="button"
                className="slds-button"
                onClick={capturePhoto}
                disabled={!cameraReady}
                style={{
                  width: '64px',
                  height: '64px',
                  borderRadius: '50%',
                  backgroundColor: cameraReady ? '#0176d3' : '#ccc',
                  border: '4px solid #fff',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.3)',
                }}
                aria-label="Capture photo"
              >
                <svg 
                  xmlns="http://www.w3.org/2000/svg" 
                  viewBox="0 0 24 24" 
                  fill="#fff"
                  style={{ width: '32px', height: '32px' }}
                >
                  <path d="M12 15a3 3 0 100-6 3 3 0 000 6z"/>
                  <path fillRule="evenodd" d="M1.323 11.447C2.811 6.976 7.028 3.75 12.001 3.75c4.97 0 9.185 3.223 10.675 7.69.12.362.12.752 0 1.113-1.487 4.471-5.705 7.697-10.677 7.697-4.97 0-9.186-3.223-10.675-7.69a1.762 1.762 0 010-1.113zM17.25 12a5.25 5.25 0 11-10.5 0 5.25 5.25 0 0110.5 0z" clipRule="evenodd"/>
                </svg>
              </button>
            </div>

            {/* Switch camera */}
            <div className="slds-col slds-size_1-of-3 slds-text-align_right">
              <button
                type="button"
                className="slds-button slds-button_neutral"
                onClick={switchCamera}
                disabled={!cameraReady}
              >
                <svg className="slds-button__icon slds-button__icon_left" aria-hidden="true">
                  <use xlinkHref="/assets/icons/utility-sprite/svg/symbols.svg#sync"></use>
                </svg>
                Flip
              </button>
            </div>
          </div>

          {onCancel && (
            <div className="slds-m-top_medium slds-text-align_center">
              <button
                type="button"
                className="slds-button slds-button_neutral"
                onClick={onCancel}
              >
                Cancel
              </button>
            </div>
          )}
        </div>
      )}

      {mode === 'preview' && capturedImage && (
        <div className="preview-view">
          <div 
            className="preview-container slds-m-bottom_medium"
            style={{
              position: 'relative',
              width: '100%',
              maxWidth: '500px',
              margin: '0 auto',
              backgroundColor: '#f3f3f3',
              borderRadius: '8px',
              overflow: 'hidden',
            }}
          >
            <img
              src={capturedImage}
              alt="Captured"
              style={{
                width: '100%',
                height: 'auto',
                display: 'block',
                transform: `rotate(${rotation}deg)`,
                transition: 'transform 0.2s ease',
              }}
            />
          </div>

          {/* Edit controls */}
          <div className="edit-controls slds-m-bottom_medium slds-text-align_center">
            <span className="slds-text-title_caps slds-m-right_medium">Rotate:</span>
            <button
              type="button"
              className="slds-button slds-button_icon slds-button_icon-border-filled slds-m-right_small"
              onClick={() => rotateImage(-90)}
              title="Rotate left"
            >
              <svg className="slds-button__icon" aria-hidden="true">
                <use xlinkHref="/assets/icons/utility-sprite/svg/symbols.svg#undo"></use>
              </svg>
              <span className="slds-assistive-text">Rotate left</span>
            </button>
            <button
              type="button"
              className="slds-button slds-button_icon slds-button_icon-border-filled"
              onClick={() => rotateImage(90)}
              title="Rotate right"
            >
              <svg className="slds-button__icon" aria-hidden="true">
                <use xlinkHref="/assets/icons/utility-sprite/svg/symbols.svg#redo"></use>
              </svg>
              <span className="slds-assistive-text">Rotate right</span>
            </button>
          </div>

          {/* Action buttons */}
          <div className="action-buttons slds-grid slds-grid_align-center slds-gutters">
            <div className="slds-col">
              <button
                type="button"
                className="slds-button slds-button_neutral"
                onClick={handleRetake}
              >
                <svg className="slds-button__icon slds-button__icon_left" aria-hidden="true">
                  <use xlinkHref="/assets/icons/utility-sprite/svg/symbols.svg#refresh"></use>
                </svg>
                Retake
              </button>
            </div>
            <div className="slds-col">
              <button
                type="button"
                className="slds-button slds-button_brand"
                onClick={handleSave}
              >
                <svg className="slds-button__icon slds-button__icon_left" aria-hidden="true">
                  <use xlinkHref="/assets/icons/utility-sprite/svg/symbols.svg#check"></use>
                </svg>
                Use Photo
              </button>
            </div>
          </div>

          {onCancel && (
            <div className="slds-m-top_medium slds-text-align_center">
              <button
                type="button"
                className="slds-button slds-button_neutral"
                onClick={onCancel}
              >
                Cancel
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default PhotoCapture;

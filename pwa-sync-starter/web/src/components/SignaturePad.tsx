import React, { useRef, useEffect, useState } from 'react';
import SignaturePad from 'signature_pad';

interface SignaturePadProps {
  onSave: (signatureData: SignatureData) => void;
  recordId?: string;
  recordType?: string;
  title?: string;
}

interface SignatureData {
  dataURL: string;
  timestamp: string;
  recordId?: string;
  recordType?: string;
}

export const SignaturePadComponent: React.FC<SignaturePadProps> = ({
  onSave,
  recordId,
  recordType,
  title = "Please sign below"
}) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const signaturePadRef = useRef<SignaturePad | null>(null);
  const [isEmpty, setIsEmpty] = useState(true);

  useEffect(() => {
    if (canvasRef.current) {
      signaturePadRef.current = new SignaturePad(canvasRef.current, {
        backgroundColor: 'rgb(255, 255, 255)',
        penColor: 'rgb(0, 0, 0)',
        onBegin: () => setIsEmpty(false),
        onEnd: () => setIsEmpty(signaturePadRef.current?.isEmpty() ?? true)
      });
      
      const resizeCanvas = () => {
        const canvas = canvasRef.current!;
        const ratio = Math.max(window.devicePixelRatio || 1, 1);
        canvas.width = canvas.offsetWidth * ratio;
        canvas.height = canvas.offsetHeight * ratio;
        canvas.getContext('2d')!.scale(ratio, ratio);
        signaturePadRef.current?.clear();
      };
      
      resizeCanvas();
      window.addEventListener('resize', resizeCanvas);
      
      return () => {
        window.removeEventListener('resize', resizeCanvas);
        signaturePadRef.current?.off();
      };
    }
  }, []);

  const handleSave = () => {
    if (signaturePadRef.current && !signaturePadRef.current.isEmpty()) {
      const signatureData: SignatureData = {
        dataURL: signaturePadRef.current.toDataURL(),
        timestamp: new Date().toISOString(),
        recordId,
        recordType
      };
      onSave(signatureData);
    }
  };

  const handleClear = () => {
    signaturePadRef.current?.clear();
    setIsEmpty(true);
  };

  return (
    <div className="signature-container">
      <h3>{title}</h3>
      <canvas
        ref={canvasRef}
        className="signature-canvas"
        style={{
          border: '1px solid #ccc',
          width: '100%',
          height: '200px',
          touchAction: 'none'
        }}
      />
      <div className="signature-controls">
        <button onClick={handleClear} type="button">
          Clear
        </button>
        <button 
          onClick={handleSave} 
          disabled={isEmpty}
          type="button"
        >
          Save Signature
        </button>
      </div>
    </div>
  );
};
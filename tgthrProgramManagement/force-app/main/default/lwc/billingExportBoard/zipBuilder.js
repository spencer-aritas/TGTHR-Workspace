/**
 * Minimal ZIP file builder (STORED, no compression).
 * Creates valid ZIP archives entirely in JavaScript.
 * Compatible with Salesforce Locker Service.
 *
 * Usage:
 *   import { createZip } from "./zipBuilder";
 *   const blob = createZip([{ name: "file.pdf", data: uint8Array }]);
 */

// Pre-compute CRC-32 lookup table (polynomial 0xEDB88320)
const CRC_TABLE = new Uint32Array(256);
for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) {
        c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    CRC_TABLE[n] = c;
}

function crc32(data) {
    let crc = 0xffffffff;
    for (let i = 0; i < data.length; i++) {
        crc = CRC_TABLE[(crc ^ data[i]) & 0xff] ^ (crc >>> 8);
    }
    return (crc ^ 0xffffffff) >>> 0;
}

function writeU16(view, offset, value) {
    view.setUint16(offset, value, true);
}

function writeU32(view, offset, value) {
    view.setUint32(offset, value, true);
}

/**
 * Build a ZIP archive from an array of file entries.
 * @param {Array<{name: string, data: Uint8Array}>} files
 * @returns {Blob} ZIP file
 */
export function createZip(files) {
    const encoder = new TextEncoder();
    const entries = files.map((f) => {
        const nameBytes = encoder.encode(f.name);
        const crcVal = crc32(f.data);
        return { nameBytes, data: f.data, crc: crcVal, size: f.data.length };
    });

    // Calculate total buffer size
    let localSize = 0;
    let centralSize = 0;
    for (const e of entries) {
        localSize += 30 + e.nameBytes.length + e.size;
        centralSize += 46 + e.nameBytes.length;
    }
    const totalSize = localSize + centralSize + 22;

    const buffer = new ArrayBuffer(totalSize);
    const view = new DataView(buffer);
    const bytes = new Uint8Array(buffer);

    let offset = 0;
    const localOffsets = [];

    // ── Local file headers + data ──
    for (const e of entries) {
        localOffsets.push(offset);

        writeU32(view, offset, 0x04034b50); // signature
        writeU16(view, offset + 4, 20); // version needed
        writeU16(view, offset + 6, 0); // flags
        writeU16(view, offset + 8, 0); // compression (stored)
        writeU16(view, offset + 10, 0); // mod time
        writeU16(view, offset + 12, 0); // mod date
        writeU32(view, offset + 14, e.crc);
        writeU32(view, offset + 18, e.size); // compressed
        writeU32(view, offset + 22, e.size); // uncompressed
        writeU16(view, offset + 26, e.nameBytes.length);
        writeU16(view, offset + 28, 0); // extra length
        offset += 30;

        bytes.set(e.nameBytes, offset);
        offset += e.nameBytes.length;

        bytes.set(e.data, offset);
        offset += e.size;
    }

    // ── Central directory ──
    const centralDirOffset = offset;
    for (let i = 0; i < entries.length; i++) {
        const e = entries[i];

        writeU32(view, offset, 0x02014b50); // signature
        writeU16(view, offset + 4, 20); // version made by
        writeU16(view, offset + 6, 20); // version needed
        writeU16(view, offset + 8, 0); // flags
        writeU16(view, offset + 10, 0); // compression
        writeU16(view, offset + 12, 0); // mod time
        writeU16(view, offset + 14, 0); // mod date
        writeU32(view, offset + 16, e.crc);
        writeU32(view, offset + 20, e.size);
        writeU32(view, offset + 24, e.size);
        writeU16(view, offset + 28, e.nameBytes.length);
        writeU16(view, offset + 30, 0); // extra length
        writeU16(view, offset + 32, 0); // comment length
        writeU16(view, offset + 34, 0); // disk start
        writeU16(view, offset + 36, 0); // internal attrs
        writeU32(view, offset + 38, 0); // external attrs
        writeU32(view, offset + 42, localOffsets[i]); // header offset
        offset += 46;

        bytes.set(e.nameBytes, offset);
        offset += e.nameBytes.length;
    }

    // ── End of central directory ──
    writeU32(view, offset, 0x06054b50);
    writeU16(view, offset + 4, 0); // disk number
    writeU16(view, offset + 6, 0); // central dir disk
    writeU16(view, offset + 8, entries.length);
    writeU16(view, offset + 10, entries.length);
    writeU32(view, offset + 12, centralSize);
    writeU32(view, offset + 16, centralDirOffset);
    writeU16(view, offset + 20, 0); // comment length

    return new Blob([buffer], { type: "application/zip" });
}

/**
 * Convert a base64 string to Uint8Array.
 * @param {string} b64
 * @returns {Uint8Array}
 */
export function base64ToBytes(b64) {
    const bin = atob(b64);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) {
        bytes[i] = bin.charCodeAt(i);
    }
    return bytes;
}

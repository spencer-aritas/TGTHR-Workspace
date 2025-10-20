/// <reference types="vite/client" />

// declare VITE_* you use so TS can autocomplete:
interface ImportMetaEnv {
  readonly VITE_API_BASE_URL?: string
}
interface ImportMeta {
  readonly env: ImportMetaEnv
}
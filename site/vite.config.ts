import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  base: '/',
  plugins: [react(), tailwindcss()],
  publicDir: 'public',
  build: {
    outDir: '../docs',
    emptyOutDir: false,
    assetsDir: 'site-assets',
    sourcemap: false,
    target: 'es2020'
  },
  server: { port: 5173, host: '127.0.0.1' }
});

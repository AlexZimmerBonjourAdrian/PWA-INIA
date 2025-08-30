import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'pwa.inia',
  appName: 'ZimmZimmGames',
  webDir: 'dist/pwa-inia-project/browser',
  server: {
    allowNavigation: ['zimmzimmgames.com']
  }
};

export default config;



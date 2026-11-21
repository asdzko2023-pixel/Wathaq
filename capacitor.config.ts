import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.wathaq.app',
  appName: 'WATHAQ',
  webDir: 'public',
  bundledWebRuntime: false,
  android: {
    allowMixedContent: false,
    captureInput: true
  }
};

export default config;

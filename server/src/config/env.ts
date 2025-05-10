import * as dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Load environment variables from .env file
export function loadEnvVariables() {
  // Load environment variables from the .env file from the root directory
  dotenv.config({ path: path.resolve(__dirname, '../../../../.env') });

  if (!process.env.AZURE_OPENAI_API_KEY) {
    throw new Error('AZURE_OPENAI_API_KEY must be configured in environment variables');
  }

  // List of required environment variables
  const requiredEnvVars = [
    'AZURE_OPENAI_API_KEY',
    'AZURE_OPENAI_ENDPOINT',
    'AZURE_OPENAI_DEPLOYMENT_NAME',
    'AZURE_OPENAI_API_VERSION'
  ];

  // Check if the environment is development
  if (process.env.NODE_ENV === 'development') {
    const missingVars = requiredEnvVars.filter(envVar => !process.env[envVar]);
    if (missingVars.length > 0) {
      console.warn(`Missing environment variables: ${missingVars.join(', ')}`);
      console.warn('Some functionalities may not work correctly in development mode.');
    }
  } else {
    // In production, throw error if any variable is missing
    for (const envVar of requiredEnvVars) {
      if (!process.env[envVar]) {
        throw new Error(`${envVar} must be configured in environment variables`);
      }
    }
  }
}

export const NODE_ENV = process.env.NODE_ENV;
export const PORT = process.env.PORT || '3000';
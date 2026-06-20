import { createClient } from '@supabase/supabase-js';
import { config } from '../config/index.js';
import { logger } from '../config/logger.js';

// Supabase Storage helper. Uses the service-role key (server-side only) to
// upload disease-scan images and return a public URL. If Supabase is not
// configured, uploads are skipped and a data-less placeholder URL is returned
// so the rest of the flow still works in local/offline dev.

let client = null;
export function getSupabase() {
  if (!config.supabase.url || !config.supabase.serviceRole) return null;
  if (!client) {
    client = createClient(config.supabase.url, config.supabase.serviceRole, {
      auth: { persistSession: false },
    });
  }
  return client;
}

// Upload an image buffer to the disease-scans bucket; returns its public URL.
export async function uploadDiseaseImage(buffer, { farmerId, contentType = 'image/jpeg' }) {
  const supabase = getSupabase();
  const ext = contentType.includes('png') ? 'png' : 'jpg';
  const objectPath = `${farmerId}/${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`;

  if (!supabase) {
    logger.warn('Supabase Storage not configured; returning placeholder image URL');
    return `local://${config.supabase.diseaseBucket}/${objectPath}`;
  }

  const { error } = await supabase.storage
    .from(config.supabase.diseaseBucket)
    .upload(objectPath, buffer, { contentType, upsert: false });
  if (error) throw error;

  const { data } = supabase.storage
    .from(config.supabase.diseaseBucket)
    .getPublicUrl(objectPath);
  return data.publicUrl;
}

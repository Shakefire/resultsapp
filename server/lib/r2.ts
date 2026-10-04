import { DeleteObjectCommand, GetObjectCommand, HeadObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { supabaseClients } from './auth.js';

export const evidenceBucket = () => process.env.R2_BUCKET_NAME || 'storageapp';

export function withEvidencePrefix(key: string): string {
  const prefix = (process.env.R2_KEY_PREFIX ?? 'inecresults/').trim();
  const segments = prefix.split('/').filter(Boolean);
  if (!segments.length || segments.some((segment) => segment === '.' || segment === '..')) {
    throw new Error('R2_KEY_PREFIX must be a non-empty object-key prefix.');
  }
  return `${segments.join('/')}/${key.replace(/^[/]+/, '')}`;
}

let client: S3Client | undefined;
function r2Client(): S3Client | null {
  const accountId = process.env.R2_ACCOUNT_ID?.trim();
  const accessKeyId = process.env.R2_ACCESS_KEY_ID?.trim();
  const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY?.trim();
  if (!accountId || !accessKeyId || !secretAccessKey || accountId.length !== 32) {
    return null;
  }
  if (client) return client;
  client = new S3Client({
    region: 'auto',
    endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
    forcePathStyle: true,
    credentials: {
      accessKeyId,
      secretAccessKey,
    },
  });
  return client;
}

const SUPABASE_BUCKET = 'evidence';

async function ensureSupabaseBucket() {
  const { adminClient } = supabaseClients();
  try {
    await adminClient.storage.createBucket(SUPABASE_BUCKET, { public: false });
  } catch (_) {}
}

export async function createUploadUrl(key: string, contentType: string): Promise<string> {
  const r2 = r2Client();
  if (r2) {
    try {
      return await getSignedUrl(r2, new PutObjectCommand({ Bucket: evidenceBucket(), Key: key, ContentType: contentType }), { expiresIn: 300 });
    } catch (e) {
      console.warn('R2 presigned upload URL creation failed, falling back to Supabase Storage', e);
    }
  }
  await ensureSupabaseBucket();
  const { adminClient } = supabaseClients();
  const { data, error } = await adminClient.storage.from(SUPABASE_BUCKET).createSignedUploadUrl(key, { upsert: true });
  if (error || !data) {
    throw new Error(`Failed to create signed upload URL: ${error?.message ?? 'unknown'}`);
  }
  return data.signedUrl;
}

export async function createDownloadUrl(key: string): Promise<string> {
  const r2 = r2Client();
  if (r2) {
    try {
      return await getSignedUrl(r2, new GetObjectCommand({ Bucket: evidenceBucket(), Key: key }), { expiresIn: 300 });
    } catch (e) {
      console.warn('R2 presigned download URL creation failed, falling back to Supabase Storage', e);
    }
  }
  const { adminClient } = supabaseClients();
  const { data, error } = await adminClient.storage.from(SUPABASE_BUCKET).createSignedUrl(key, 300);
  if (error || !data) {
    throw new Error(`Failed to create signed download URL: ${error?.message ?? 'unknown'}`);
  }
  return data.signedUrl;
}

export async function inspectObject(key: string): Promise<{ ContentLength?: number; ContentType?: string }> {
  const r2 = r2Client();
  if (r2) {
    try {
      const res = await r2.send(new HeadObjectCommand({ Bucket: evidenceBucket(), Key: key }));
      return { ContentLength: res.ContentLength, ContentType: res.ContentType };
    } catch (_) {}
  }
  const { adminClient } = supabaseClients();
  const parts = key.split('/');
  const fileName = parts.pop()!;
  const folder = parts.join('/');
  const { data } = await adminClient.storage.from(SUPABASE_BUCKET).list(folder, { search: fileName });
  const file = data?.find((f) => f.name === fileName);
  if (!file) throw new Error('Object not found in storage');
  const size = file.metadata?.size ?? file.metadata?.contentLength ?? 0;
  const mime = file.metadata?.mimetype ?? 'application/octet-stream';
  return { ContentLength: size, ContentType: mime };
}

export async function deleteObject(key: string): Promise<void> {
  const r2 = r2Client();
  if (r2) {
    try {
      await r2.send(new DeleteObjectCommand({ Bucket: evidenceBucket(), Key: key }));
    } catch (_) {}
  }
  const { adminClient } = supabaseClients();
  await adminClient.storage.from(SUPABASE_BUCKET).remove([key]);
}

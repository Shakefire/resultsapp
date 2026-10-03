import { DeleteObjectCommand, GetObjectCommand, HeadObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

function requiredEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

export const evidenceBucket = () => requiredEnv('R2_BUCKET_NAME');
let client: S3Client | undefined;
function r2Client(): S3Client {
  if (client) return client;
  const accountId = requiredEnv('R2_ACCOUNT_ID');
  client = new S3Client({
    region: 'auto',
    endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: requiredEnv('R2_ACCESS_KEY_ID'),
      secretAccessKey: requiredEnv('R2_SECRET_ACCESS_KEY'),
    },
  });
  return client;
}

export async function createUploadUrl(key: string, contentType: string): Promise<string> {
  return getSignedUrl(r2Client(), new PutObjectCommand({ Bucket: evidenceBucket(), Key: key, ContentType: contentType }), { expiresIn: 300 });
}

export async function createDownloadUrl(key: string): Promise<string> {
  return getSignedUrl(r2Client(), new GetObjectCommand({ Bucket: evidenceBucket(), Key: key }), { expiresIn: 300 });
}

export async function inspectObject(key: string) {
  return r2Client().send(new HeadObjectCommand({ Bucket: evidenceBucket(), Key: key }));
}

export async function deleteObject(key: string): Promise<void> {
  await r2Client().send(new DeleteObjectCommand({ Bucket: evidenceBucket(), Key: key }));
}

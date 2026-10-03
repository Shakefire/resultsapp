import type { VercelRequest, VercelResponse } from '@vercel/node';

export type ApiErrorCode =
  | 'VALIDATION_ERROR'
  | 'METHOD_NOT_ALLOWED'
  | 'UNAUTHORIZED'
  | 'FORBIDDEN'
  | 'NOT_FOUND'
  | 'CONFLICT'
  | 'WORKFLOW_ERROR'
  | 'INCOMPLETE_SUMMARY'
  | 'CONFIGURATION_ERROR'
  | 'INTERNAL_ERROR';

export function setCorsHeaders(req: VercelRequest, res: VercelResponse): boolean {
  const origin = req.headers.origin;
  const allowedOrigins = (process.env.APP_ORIGINS ?? '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);

  res.setHeader('Vary', 'Origin');
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, OPTIONS');
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('X-Content-Type-Options', 'nosniff');

  // Native Flutter clients normally omit Origin. Browser clients must be listed
  // explicitly in APP_ORIGINS; wildcard CORS is intentionally unsupported.
  if (typeof origin === 'string') {
    if (!allowedOrigins.includes(origin)) return false;
    res.setHeader('Access-Control-Allow-Origin', origin);
  }
  return true;
}

export function sendError(
  res: VercelResponse,
  status: number,
  code: ApiErrorCode,
  message: string,
): void {
  res.status(status).json({ error: { code, message } });
}

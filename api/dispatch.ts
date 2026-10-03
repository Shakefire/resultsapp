import type { VercelRequest, VercelResponse } from '@vercel/node';
import accounts from '../server/routes/v1/admin/accounts.js';
import elections from '../server/routes/v1/admin/elections.js';
import adminGeography from '../server/routes/v1/admin/geography.js';
import users from '../server/routes/v1/admin/users.js';
import login from '../server/routes/v1/auth/login.js';
import password from '../server/routes/v1/auth/password.js';
import openElection from '../server/routes/v1/elections/open.js';
import downloadUrl from '../server/routes/v1/evidence/download-url.js';
import uploadUrl from '../server/routes/v1/evidence/upload-url.js';
import voterRegister from '../server/routes/v1/evidence/voter-register.js';
import geography from '../server/routes/v1/geography.js';
import me from '../server/routes/v1/me.js';
import stateSummary from '../server/routes/v1/reports/state-summary.js';
import decisions from '../server/routes/v1/workflow/decisions.js';
import myRecords from '../server/routes/v1/workflow/my-records.js';
import reviewQueue from '../server/routes/v1/workflow/review-queue.js';
import submissions from '../server/routes/v1/workflow/submissions.js';
import summaryApprovals from '../server/routes/v1/workflow/summary-approvals.js';
import summaryReadiness from '../server/routes/v1/workflow/summary-readiness.js';
import { sendError, setCorsHeaders } from '../server/lib/http.js';

type Handler = (req: VercelRequest, res: VercelResponse) => unknown;

// Explicit route allowlist: a path can select a handler, never a role or scope.
const routes: Record<string, Handler> = {
  '/api/v1/admin/accounts': accounts,
  '/api/v1/admin/elections': elections,
  '/api/v1/admin/geography': adminGeography,
  '/api/v1/admin/users': users,
  '/api/v1/auth/login': login,
  '/api/v1/auth/password': password,
  '/api/v1/elections/open': openElection,
  '/api/v1/evidence/download-url': downloadUrl,
  '/api/v1/evidence/upload-url': uploadUrl,
  '/api/v1/evidence/voter-register': voterRegister,
  '/api/v1/geography': geography,
  '/api/v1/me': me,
  '/api/v1/reports/state-summary': stateSummary,
  '/api/v1/workflow/decisions': decisions,
  '/api/v1/workflow/my-records': myRecords,
  '/api/v1/workflow/review-queue': reviewQueue,
  '/api/v1/workflow/submissions': submissions,
  '/api/v1/workflow/summary-approvals': summaryApprovals,
  '/api/v1/workflow/summary-readiness': summaryReadiness,
};

function requestedPath(req: VercelRequest): string | null {
  const requestPath = new URL(req.url ?? '/', 'https://vercel.invalid').pathname;
  if (requestPath.startsWith('/api/v1/')) return requestPath.replace(/\/+$/, '') || '/';

  // vercel.json rewrites /api/v1/* to this one function and carries the
  // captured suffix in __route. Direct requests to /api/dispatch have no route.
  const captured = req.query.__route;
  if (typeof captured !== 'string' && !Array.isArray(captured)) return null;
  const suffix = (Array.isArray(captured) ? captured.join('/') : captured)
    .replace(/^\/+/, '')
    .replace(/\/+$/, '');
  if (!suffix || suffix.includes('..')) return null;
  return `/api/v1/${suffix}`;
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  const path = requestedPath(req);
  const route = path ? routes[path] : undefined;
  if (!route) {
    if (!setCorsHeaders(req, res)) {
      return sendError(res, 403, 'FORBIDDEN', 'This origin is not allowed.');
    }
    return sendError(res, 404, 'NOT_FOUND', 'API route not found.');
  }
  return route(req, res);
}

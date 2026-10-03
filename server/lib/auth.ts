import { createClient, type User } from '@supabase/supabase-js';
import type { VercelRequest, VercelResponse } from '@vercel/node';
import { sendError } from './http.js';

export type AppRole =
  | 'super_admin'
  | 'state_admin'
  | 'lga_admin'
  | 'ward_admin'
  | 'polling_unit_staff';

export interface UserProfile {
  auth_user_id: string;
  user_id: string;
  full_name: string;
  role: AppRole;
  state_code: string | null;
  lga_code: string | null;
  ward_code: string | null;
  polling_unit_code: string | null;
  is_active: boolean;
  must_change_password: boolean;
}

export interface AuthenticatedPrincipal {
  authUser: User;
  profile: UserProfile;
}

function requiredEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

export function supabaseClients() {
  const url = requiredEnv('SUPABASE_URL');
  const anonKey = requiredEnv('SUPABASE_ANON_KEY');
  const serviceRoleKey = requiredEnv('SUPABASE_SERVICE_ROLE_KEY');
  return {
    authClient: createClient(url, anonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    }),
    adminClient: createClient(url, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    }),
  };
}

export async function authenticateRequest(
  req: VercelRequest,
  res: VercelResponse,
): Promise<AuthenticatedPrincipal | null> {
  const authorization = req.headers.authorization;
  const match = typeof authorization === 'string'
    ? /^Bearer\s+([^\s]+)$/i.exec(authorization)
    : null;
  if (!match) {
    sendError(res, 401, 'UNAUTHORIZED', 'A valid bearer token is required.');
    return null;
  }

  try {
    const { authClient, adminClient } = supabaseClients();
    // getUser(token) verifies the token with Supabase Auth; do not trust decoded
    // client claims as the source of account role or location.
    const { data: authData, error: authError } = await authClient.auth.getUser(match[1]);
    if (authError || !authData.user) {
      sendError(res, 401, 'UNAUTHORIZED', 'The session is invalid or expired.');
      return null;
    }

    const { data: profile, error: profileError } = await adminClient
      .from('user_profiles')
      .select('auth_user_id,user_id,full_name,role,state_code,lga_code,ward_code,polling_unit_code,is_active,must_change_password')
      .eq('auth_user_id', authData.user.id)
      .maybeSingle<UserProfile>();

    if (profileError) {
      console.error('Profile lookup failed', profileError.code);
      sendError(res, 500, 'INTERNAL_ERROR', 'Unable to load the account profile.');
      return null;
    }
    if (!profile || !profile.is_active) {
      sendError(res, 403, 'FORBIDDEN', 'This account is not provisioned or is inactive.');
      return null;
    }

    return { authUser: authData.user, profile };
  } catch (error) {
    if (error instanceof Error && error.message.startsWith('Missing required environment variable:')) {
      console.error(error.message);
      sendError(res, 500, 'CONFIGURATION_ERROR', 'The API is not configured.');
      return null;
    }
    console.error('Authentication middleware failed');
    sendError(res, 500, 'INTERNAL_ERROR', 'Unable to authenticate this request.');
    return null;
  }
}

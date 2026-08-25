/**
 * SwiftBite — Menu Image Presigner Worker
 *
 * Endpoints
 * ─────────
 *   GET /img/{objectKey}
 *     Public — no auth required. Serves the image directly from R2.
 *     Example: GET /img/restaurants/RID/menu/IID/main.webp
 *
 *   POST /api/menu-images/presign
 *     Body: { menuItemId: string, imageType: "main" | "hero" }
 *     Auth: Authorization: Bearer <Firebase ID Token>
 *     Returns: { uploadUrl, publicUrl, objectKey, expiresAt }
 *
 *   DELETE /api/menu-images/delete
 *     Body: { objectKey: string }
 *     Auth: Authorization: Bearer <Firebase ID Token>
 *     Returns: { success: true }
 *
 * Security invariants enforced here (not in Flutter)
 * ────────────────────────────────────────────────────
 *   1. Firebase ID token must be valid and not expired.
 *   2. User must have role === "restaurant_owner" in Firestore.
 *   3. User must have a restaurantId in Firestore.
 *   4. Requested path must start with restaurants/{userRestaurantId}/.
 *   5. menuItemId must not contain path-traversal characters.
 */

// ── Environment bindings ──────────────────────────────────────────────────────

interface Env {
  // R2 bucket binding (for direct put/delete without presigning)
  MENU_IMAGES: R2Bucket;

  // Vars from wrangler.toml
  FIREBASE_PROJECT_ID: string;
  R2_BUCKET_NAME: string;
  R2_ACCOUNT_ID: string;
  R2_PUBLIC_BASE_URL: string;

  // Secrets set via `wrangler secret put`
  R2_ACCESS_KEY_ID: string;
  R2_SECRET_ACCESS_KEY: string;
}

// ── CORS helpers ──────────────────────────────────────────────────────────────

const CORS_HEADERS: HeadersInit = {
  'Access-Control-Allow-Origin': '*', // tighten to your domain in production
  'Access-Control-Allow-Methods': 'POST, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

function corsJson(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

function corsError(message: string, status: number): Response {
  return corsJson({ error: message }, status);
}

// ── Main handler ──────────────────────────────────────────────────────────────

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);

    // ── Public image serving ────────────────────────────────────────────────
    // GET /img/restaurants/{restaurantId}/menu/{itemId}/main.webp
    // Served directly from the R2 binding — no auth required, fully reliable.
    if (request.method === 'GET' && url.pathname.startsWith('/img/')) {
      return handleImageServe(url.pathname, env);
    }

    if (request.method === 'POST' && url.pathname === '/api/menu-images/presign') {
      return handlePresign(request, env);
    }

    if (request.method === 'DELETE' && url.pathname === '/api/menu-images/delete') {
      return handleDelete(request, env);
    }

    return corsError('Not found', 404);
  },
};

// ── GET /img/{objectKey} — public image serving ───────────────────────────────
//
// Reads objects directly from the R2 bucket binding (env.MENU_IMAGES).
// No credentials needed. The Worker URL is the stable public delivery URL.
// Cache-Control is set so Cloudflare's CDN caches images at the edge.

async function handleImageServe(pathname: string, env: Env): Promise<Response> {
  // Strip the leading /img/ prefix to get the object key
  const objectKey = pathname.slice('/img/'.length);

  // Basic sanity check — must start with restaurants/
  if (!objectKey.startsWith('restaurants/')) {
    return new Response('Not found', { status: 404 });
  }

  const object = await env.MENU_IMAGES.get(objectKey);

  if (object === null) {
    return new Response('Image not found', { status: 404 });
  }

  const headers = new Headers();
  headers.set('Content-Type', object.httpMetadata?.contentType ?? 'image/webp');
  headers.set('Cache-Control', 'public, max-age=31536000, immutable');
  headers.set('ETag', object.httpEtag);

  return new Response(object.body, { headers });
}

// ── POST /api/menu-images/presign ─────────────────────────────────────────────

async function handlePresign(request: Request, env: Env): Promise<Response> {
  // 1. Extract + verify Firebase ID token
  const token = extractBearerToken(request);
  if (!token) return corsError('Missing or invalid Authorization header', 401);

  let uid: string;
  try {
    uid = await verifyFirebaseToken(token, env.FIREBASE_PROJECT_ID);
  } catch (e) {
    return corsError('Unauthorized: invalid or expired token', 401);
  }

  // 2. Parse request body
  let body: { menuItemId?: string; imageType?: string };
  try {
    body = await request.json();
  } catch {
    return corsError('Invalid JSON body', 400);
  }

  const { menuItemId, imageType } = body;

  if (!menuItemId || typeof menuItemId !== 'string') {
    return corsError('menuItemId is required', 400);
  }
  if (!imageType || (imageType !== 'main' && imageType !== 'hero')) {
    return corsError('imageType must be "main" or "hero"', 400);
  }

  // 3. Sanitise menuItemId — reject path traversal or suspicious chars
  if (!/^[a-zA-Z0-9_-]{1,128}$/.test(menuItemId)) {
    return corsError('menuItemId contains invalid characters', 400);
  }

  // 4. Look up the user's restaurantId + role in Firestore
  let restaurantId: string;
  try {
    const profile = await fetchFirestoreUserProfile(uid, env.FIREBASE_PROJECT_ID, token);
    if (!profile) return corsError('User profile not found', 403);
    if (profile.role !== 'restaurant_owner') return corsError('Forbidden: not a restaurant owner', 403);
    if (!profile.restaurantId) return corsError('Forbidden: no restaurant associated with this account', 403);
    restaurantId = profile.restaurantId;
  } catch (e) {
    return corsError('Failed to verify restaurant ownership', 500);
  }

  // 5. Build the object key — always scoped to the authenticated owner's restaurant
  const fileName = imageType === 'hero' ? 'hero.webp' : 'main.webp';
  const objectKey = `restaurants/${restaurantId}/menu/${menuItemId}/${fileName}`;

  // 6. Generate presigned PUT URL (15-minute expiry)
  const EXPIRY_SECONDS = 900;
  let uploadUrl: string;
  try {
    uploadUrl = await generatePresignedPutUrl({
      accountId: env.R2_ACCOUNT_ID,
      bucketName: env.R2_BUCKET_NAME,
      objectKey,
      accessKeyId: env.R2_ACCESS_KEY_ID,
      secretAccessKey: env.R2_SECRET_ACCESS_KEY,
      expirySeconds: EXPIRY_SECONDS,
    });
  } catch (e) {
    return corsError('Failed to generate upload URL', 500);
  }

  const publicUrl = `${env.R2_PUBLIC_BASE_URL.replace(/\/$/, '')}/img/${objectKey}`;
  const expiresAt = new Date(Date.now() + EXPIRY_SECONDS * 1000).toISOString();

  return corsJson({ uploadUrl, publicUrl, objectKey, expiresAt });
}

// ── DELETE /api/menu-images/delete ────────────────────────────────────────────

async function handleDelete(request: Request, env: Env): Promise<Response> {
  // 1. Verify Firebase token
  const token = extractBearerToken(request);
  if (!token) return corsError('Missing or invalid Authorization header', 401);

  let uid: string;
  try {
    uid = await verifyFirebaseToken(token, env.FIREBASE_PROJECT_ID);
  } catch {
    return corsError('Unauthorized: invalid or expired token', 401);
  }

  // 2. Parse body
  let body: { objectKey?: string };
  try {
    body = await request.json();
  } catch {
    return corsError('Invalid JSON body', 400);
  }

  const { objectKey } = body;
  if (!objectKey || typeof objectKey !== 'string') {
    return corsError('objectKey is required', 400);
  }

  // 3. Get the user's restaurantId and verify the objectKey belongs to them
  let restaurantId: string;
  try {
    const profile = await fetchFirestoreUserProfile(uid, env.FIREBASE_PROJECT_ID, token);
    if (!profile) return corsError('User profile not found', 403);
    if (profile.role !== 'restaurant_owner') return corsError('Forbidden: not a restaurant owner', 403);
    if (!profile.restaurantId) return corsError('Forbidden: no restaurant associated', 403);
    restaurantId = profile.restaurantId;
  } catch {
    return corsError('Failed to verify restaurant ownership', 500);
  }

  // 4. Verify the object key path is scoped to this owner's restaurant
  const expectedPrefix = `restaurants/${restaurantId}/`;
  if (!objectKey.startsWith(expectedPrefix)) {
    return corsError('Forbidden: object does not belong to your restaurant', 403);
  }

  // 5. Delete from R2 via the bucket binding
  try {
    await env.MENU_IMAGES.delete(objectKey);
  } catch {
    return corsError('Failed to delete image from storage', 500);
  }

  return corsJson({ success: true });
}

// ── Firebase token verification ───────────────────────────────────────────────
//
// Verifies a Firebase ID token using Firebase's public JWKS endpoint.
// This is pure JWT verification — no Admin SDK required in the Worker.
//
// Firebase ID token structure:
//   header.payload.signature  (RS256)
//
// Public keys: https://www.googleapis.com/robot/v1/metadata/jwk/securetoken@system.gserviceaccount.com

async function verifyFirebaseToken(token: string, projectId: string): Promise<string> {
  // Split JWT
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('Invalid JWT format');

  // Decode header to get key ID
  const header = JSON.parse(base64UrlDecode(parts[0])) as { kid: string; alg: string };
  if (header.alg !== 'RS256') throw new Error('Unexpected JWT algorithm');

  // Decode payload
  const payload = JSON.parse(base64UrlDecode(parts[1])) as {
    iss: string;
    aud: string;
    sub: string;
    exp: number;
    iat: number;
    uid?: string;
    user_id?: string;
  };

  // Validate standard claims
  const now = Math.floor(Date.now() / 1000);
  if (payload.exp < now) throw new Error('Token expired');
  if (payload.iat > now + 300) throw new Error('Token issued in the future');
  if (payload.aud !== projectId) throw new Error('Token audience mismatch');
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
    throw new Error('Token issuer mismatch');
  }

  // Fetch Firebase public keys (cached by CF edge; ~6h TTL on the response)
  const jwksRes = await fetch(
    'https://www.googleapis.com/robot/v1/metadata/jwk/securetoken@system.gserviceaccount.com',
    { cf: { cacheTtl: 3600, cacheEverything: true } } as RequestInit,
  );
  if (!jwksRes.ok) throw new Error('Could not fetch Firebase public keys');
  const jwks = (await jwksRes.json()) as { keys: JsonWebKey[] };

  // Find the key matching our token's kid
  const jwk = jwks.keys.find((k) => (k as { kid?: string }).kid === header.kid);
  if (!jwk) throw new Error('No matching public key found');

  // Import the JWK and verify the signature
  const cryptoKey = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );

  const signingInput = `${parts[0]}.${parts[1]}`;
  const signature = base64UrlToUint8Array(parts[2]);

  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    signature,
    new TextEncoder().encode(signingInput),
  );

  if (!valid) throw new Error('Invalid JWT signature');

  // Return the Firebase uid (sub claim)
  const uid = payload.sub || payload.uid || payload.user_id;
  if (!uid) throw new Error('No uid in token payload');
  return uid;
}

// ── Firestore REST: fetch user profile ───────────────────────────────────────

interface UserProfileDoc {
  role: string;
  restaurantId?: string;
}

async function fetchFirestoreUserProfile(
  uid: string,
  projectId: string,
  idToken: string,
): Promise<UserProfileDoc | null> {
  // Use the Firestore REST API with the user's own ID token.
  // This is safe because Firestore security rules allow users to read their
  // own document (match /users/{uid} { allow read: if isOwner(uid); }).
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${uid}`;

  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${idToken}` },
  });

  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`Firestore read failed: ${res.status}`);

  const doc = (await res.json()) as {
    fields?: {
      role?: { stringValue?: string };
      restaurantId?: { stringValue?: string };
    };
  };

  if (!doc.fields) return null;

  return {
    role: doc.fields.role?.stringValue ?? 'customer',
    restaurantId: doc.fields.restaurantId?.stringValue,
  };
}

// ── AWS Signature V4 presigned URL for R2 (S3-compatible) ─────────────────────
//
// Cloudflare R2 is S3-compatible. Presigned PUTs use AWS Signature Version 4.
// We implement the signing from scratch since no AWS SDK runs in Workers.

interface PresignOptions {
  accountId: string;
  bucketName: string;
  objectKey: string;
  accessKeyId: string;
  secretAccessKey: string;
  expirySeconds: number;
}

async function generatePresignedPutUrl(opts: PresignOptions): Promise<string> {
  const {
    accountId, bucketName, objectKey,
    accessKeyId, secretAccessKey,
    expirySeconds,
  } = opts;

  // R2 S3-compatible endpoint.
  // Path-style URL: https://{accountId}.r2.cloudflarestorage.com/{bucket}/{key}
  const host = `${accountId}.r2.cloudflarestorage.com`;
  const region = 'auto';
  const service = 's3';

  const now = new Date();
  const amzDate = formatAmzDate(now);     // e.g. 20240101T120000Z
  const dateStamp = amzDate.slice(0, 8);  // e.g. 20240101

  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
  const credential = `${accessKeyId}/${credentialScope}`;

  // The full path includes the bucket name — this is what R2 expects and
  // what must be signed.
  const encodedKey = encodeObjectKey(objectKey);
  const canonicalPath = `/${bucketName}/${encodedKey}`;

  // Canonical query string — parameters MUST be sorted lexicographically.
  const rawParams: [string, string][] = [
    ['X-Amz-Algorithm', 'AWS4-HMAC-SHA256'],
    ['X-Amz-Credential', credential],
    ['X-Amz-Date', amzDate],
    ['X-Amz-Expires', String(expirySeconds)],
    ['X-Amz-SignedHeaders', 'host'],
  ];
  const sortedParams = rawParams
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
    .join('&');

  // Canonical request — path, query, headers, and payload marker must all
  // match exactly what R2 will reconstruct when validating the signature.
  const canonicalRequest = [
    'PUT',
    canonicalPath,
    sortedParams,
    `host:${host}\n`,  // canonical headers block — trailing newline required
    'host',            // signed headers list
    'UNSIGNED-PAYLOAD',
  ].join('\n');

  // String to sign
  const canonicalHash = await sha256Hex(canonicalRequest);
  const stringToSign = [
    'AWS4-HMAC-SHA256',
    amzDate,
    credentialScope,
    canonicalHash,
  ].join('\n');

  // Derive signing key and produce the signature
  const signingKey = await deriveSigningKey(secretAccessKey, dateStamp, region, service);
  const signature = await hmacHex(signingKey, stringToSign);

  // Final presigned URL — path-style with bucket in the path
  return `https://${host}${canonicalPath}?${sortedParams}&X-Amz-Signature=${signature}`;
}

// ── Crypto helpers ────────────────────────────────────────────────────────────

async function sha256Hex(data: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(data));
  return toHex(new Uint8Array(buf));
}

async function hmacSha256(key: ArrayBuffer | Uint8Array, data: string): Promise<ArrayBuffer> {
  const cryptoKey = await crypto.subtle.importKey(
    'raw', key, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  return crypto.subtle.sign('HMAC', cryptoKey, new TextEncoder().encode(data));
}

async function hmacHex(key: ArrayBuffer | Uint8Array, data: string): Promise<string> {
  return toHex(new Uint8Array(await hmacSha256(key, data)));
}

async function deriveSigningKey(
  secretKey: string,
  dateStamp: string,
  region: string,
  service: string,
): Promise<ArrayBuffer> {
  const kDate    = await hmacSha256(new TextEncoder().encode(`AWS4${secretKey}`), dateStamp);
  const kRegion  = await hmacSha256(kDate, region);
  const kService = await hmacSha256(kRegion, service);
  return hmacSha256(kService, 'aws4_request');
}

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes).map((b) => b.toString(16).padStart(2, '0')).join('');
}

function formatAmzDate(d: Date): string {
  return d.toISOString().replace(/[-:]/g, '').replace(/\.\d+/, '');
}

function encodeObjectKey(key: string): string {
  // Encode each path segment individually (do not encode slashes)
  return key.split('/').map((seg) => encodeURIComponent(seg)).join('/');
}

// ── JWT / Base64 helpers ──────────────────────────────────────────────────────

function base64UrlDecode(s: string): string {
  const padded = s.replace(/-/g, '+').replace(/_/g, '/').padEnd(s.length + (4 - s.length % 4) % 4, '=');
  return atob(padded);
}

function base64UrlToUint8Array(s: string): Uint8Array {
  const binary = base64UrlDecode(s);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function extractBearerToken(request: Request): string | null {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null;
  const token = authHeader.slice(7).trim();
  return token.length > 0 ? token : null;
}

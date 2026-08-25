# SwiftBite — Menu Image Presigner Worker

Cloudflare Worker that provides secure signed upload URLs for menu item images
stored in Cloudflare R2. The Flutter app never receives R2 credentials.

## Architecture

```
Flutter App
  → Firebase ID Token
  → POST /api/menu-images/presign
  → Worker verifies token with Firebase JWKS
  → Worker reads users/{uid}.restaurantId from Firestore
  → Worker validates path belongs to that restaurant
  → Worker returns presigned PUT URL (15 min TTL)
  → Flutter PUTs image directly to R2
  → Flutter saves publicUrl to Firestore menu_items.img
```

## Prerequisites

- Node.js ≥ 18
- Wrangler CLI: `npm install -g wrangler`
- Cloudflare account with R2 enabled
- Firebase project (`lakesebu-dcd8c`)

## Setup

### 1. Install dependencies

```bash
cd cloudflare_worker
npm install
```

### 2. Create the R2 bucket

```bash
wrangler r2 bucket create lake-sebu-menu-images
```

Enable public access in the Cloudflare dashboard:
R2 → lake-sebu-menu-images → Settings → Public Access → Allow Access

Copy the `r2.dev` public URL and update `R2_PUBLIC_BASE_URL` in `wrangler.toml`.

### 3. Create an R2 API token

Cloudflare dashboard → R2 → Manage R2 API Tokens → Create API Token
- Permissions: Object Read & Write
- Bucket: lake-sebu-menu-images

Note the **Access Key ID** and **Secret Access Key**.

### 4. Get your Cloudflare Account ID

Cloudflare dashboard → top-right → your account → copy Account ID.
Update `R2_ACCOUNT_ID` in `wrangler.toml`.

### 5. Set secrets (never committed to git)

```bash
wrangler secret put R2_ACCESS_KEY_ID
# paste your Access Key ID

wrangler secret put R2_SECRET_ACCESS_KEY
# paste your Secret Access Key
```

### 6. Update wrangler.toml

Replace the placeholder values:
- `R2_ACCOUNT_ID` → your Cloudflare Account ID
- `R2_PUBLIC_BASE_URL` → your r2.dev or custom domain URL

### 7. Deploy

```bash
wrangler deploy
```

The Worker URL will be printed: `https://lake-sebu-menu-images.<your-subdomain>.workers.dev`

Copy this URL and paste it into the Flutter app's `MenuImageService` as `_workerBaseUrl`.

## Endpoints

### POST /api/menu-images/presign

Request:
```json
{
  "menuItemId": "abc123",
  "imageType": "main"
}
```

Headers:
```
Authorization: Bearer <Firebase ID Token>
Content-Type: application/json
```

Response:
```json
{
  "uploadUrl": "https://ACCOUNT.r2.cloudflarestorage.com/restaurants/RID/menu/abc123/main.webp?X-Amz-...",
  "publicUrl": "https://pub-XXXX.r2.dev/restaurants/RID/menu/abc123/main.webp",
  "objectKey": "restaurants/RID/menu/abc123/main.webp",
  "expiresAt": "2024-01-01T12:15:00.000Z"
}
```

### DELETE /api/menu-images/delete

Request:
```json
{
  "objectKey": "restaurants/RID/menu/abc123/main.webp"
}
```

Headers:
```
Authorization: Bearer <Firebase ID Token>
Content-Type: application/json
```

Response:
```json
{ "success": true }
```

## Security

- All requests require a valid Firebase ID token (RS256 verified against Firebase JWKS).
- The user's `restaurantId` is read from Firestore server-side — never trusted from the client.
- Object key path is validated to start with `restaurants/{userRestaurantId}/`.
- No R2 credentials are ever sent to the Flutter app.

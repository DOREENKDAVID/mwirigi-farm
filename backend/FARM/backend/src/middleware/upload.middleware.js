import path from "node:path";
import fs from "node:fs";
import crypto from "node:crypto";
import multer from "multer";

// Where uploaded files live. We resolve from the project root so the
// path stays correct regardless of which subdirectory the dev server
// was launched from.
//
// Layout on disk:
//   <repo>/backend/uploads/cows/<uuid>.<ext>
//
// Express serves these via `app.use('/uploads', express.static(...))`
// so the public URL is `/uploads/cows/<uuid>.<ext>`.
const UPLOAD_ROOT = path.resolve(process.cwd(), "uploads");
const COWS_DIR = path.join(UPLOAD_ROOT, "cows");

// Ensure the cow upload directory exists before multer tries to write
// into it. Idempotent.
fs.mkdirSync(COWS_DIR, { recursive: true });

const ALLOWED_MIME = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
]);

const ALLOWED_EXT = new Set([".jpg", ".jpeg", ".png", ".webp"]);

// Generate a stable, opaque filename. We don't trust the client name
// (could contain path traversal, spaces, weird chars).
const newFilename = (original) => {
  const ext = path.extname(original).toLowerCase();
  const safeExt = ALLOWED_EXT.has(ext) ? ext : ".jpg";
  return `${crypto.randomUUID()}${safeExt}`;
};

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, COWS_DIR),
  filename: (_req, file, cb) => cb(null, newFilename(file.originalname)),
});

// Reject anything that isn't a supported image MIME. multer will pass
// the error to the route handler so the client gets a clean 400.
const fileFilter = (_req, file, cb) => {
  if (!ALLOWED_MIME.has(file.mimetype)) {
    return cb(
      new Error(
        `Unsupported image type "${file.mimetype}". Use JPEG, PNG, or WebP.`,
      ),
    );
  }
  cb(null, true);
};

// 4 MB ceiling — generous for a phone photo, conservative enough to
// keep the static-served directory small.
export const cowImageUpload = multer({
  storage,
  fileFilter,
  limits: { fileSize: 4 * 1024 * 1024 },
});

// Public path for a stored file. Combined with API_BASE_URL on the
// frontend to render the photo.
export const cowImagePublicPath = (filename) => `/uploads/cows/${filename}`;

// Used by app.js to wire `app.use('/uploads', express.static(UPLOAD_ROOT))`.
export const UPLOAD_STATIC_ROOT = UPLOAD_ROOT;

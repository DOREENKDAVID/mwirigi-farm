import "dotenv/config";
import multer from "multer";
import { v2 as cloudinary } from "cloudinary";

// =====================================================================
// IMAGE UPLOAD — Cloudinary backend
// =====================================================================
// Previous approach (local disk via multer.diskStorage + Express static)
// is preserved as a comment block at the bottom for reference. New flow:
//
//   1. multer.memoryStorage() keeps the file in RAM as a Buffer
//   2. uploadBufferToCloudinary() streams that buffer to Cloudinary
//   3. We persist Cloudinary's `secure_url` in the Cow.imageUrl column
//
// `Cow.imageUrl` is a free-form String? in the schema, so the migration
// is transparent: new rows store https://res.cloudinary.com/...; old
// rows with /uploads/cows/... paths remain readable but won't resolve
// once the static handler is disabled.

// Configure once at module load. Credentials live in backend/.env.
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
  secure: true,
});

const ALLOWED_MIME = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
]);

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

// Hold the file in memory; we hand the Buffer straight to Cloudinary
// rather than writing to disk first.
export const cowImageUpload = multer({
  storage: multer.memoryStorage(),
  fileFilter,
  limits: { fileSize: 4 * 1024 * 1024 }, // 4 MB
});

// Streams `buffer` to Cloudinary under `folder` and resolves with the
// upload result (we use `secure_url` + `public_id` downstream).
// `cloudinary.uploader.upload` only accepts a path; for in-memory
// buffers we use `upload_stream` and pipe the buffer in.
export const uploadBufferToCloudinary = (buffer, { folder = "mwirigi/cows" } = {}) =>
  new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      {
        folder,
        resource_type: "image",
        // Cloudinary auto-derives the extension; we keep our own UUID
        // off the request to avoid trusting client filenames.
      },
      (err, result) => {
        if (err) return reject(err);
        resolve(result);
      },
    );
    stream.end(buffer);
  });

// Re-exported so callers don't have to import from `cloudinary` directly
// (e.g. delete endpoints that need to clean up by public_id).
export { cloudinary };

// =====================================================================
// LEGACY: local-disk storage. Kept as a comment per migration request —
// uncomment + revert uploads.routes.js / app.js to restore the previous
// behaviour. The `uploads/` folder is also no longer required at
// runtime; existing files there are orphaned but harmless.
// =====================================================================
//
// import path from "node:path";
// import fs from "node:fs";
// import crypto from "node:crypto";
//
// const UPLOAD_ROOT = path.resolve(process.cwd(), "uploads");
// const COWS_DIR = path.join(UPLOAD_ROOT, "cows");
// fs.mkdirSync(COWS_DIR, { recursive: true });
//
// const ALLOWED_EXT = new Set([".jpg", ".jpeg", ".png", ".webp"]);
//
// const newFilename = (original) => {
//   const ext = path.extname(original).toLowerCase();
//   const safeExt = ALLOWED_EXT.has(ext) ? ext : ".jpg";
//   return `${crypto.randomUUID()}${safeExt}`;
// };
//
// const storage = multer.diskStorage({
//   destination: (_req, _file, cb) => cb(null, COWS_DIR),
//   filename: (_req, file, cb) => cb(null, newFilename(file.originalname)),
// });
//
// export const cowImageUpload = multer({
//   storage,
//   fileFilter,
//   limits: { fileSize: 4 * 1024 * 1024 },
// });
//
// export const cowImagePublicPath = (filename) => `/uploads/cows/${filename}`;
// export const UPLOAD_STATIC_ROOT = UPLOAD_ROOT;

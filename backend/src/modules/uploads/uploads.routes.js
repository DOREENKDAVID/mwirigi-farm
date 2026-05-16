import express from "express";
import {
  authMiddleware,
  authorizeRoles,
} from "../../middleware/auth.middleware.js";
import {
  cowImageUpload,
  uploadBufferToCloudinary,
} from "../../middleware/upload.middleware.js";

const router = express.Router();

// POST /api/uploads/cows
//
// Accepts a single file under the form field `image`. Streams it to
// Cloudinary and returns `{ imageUrl }` — Cloudinary's secure_url —
// which the frontend stores directly in Cow.imageUrl (no need for an
// API_BASE prefix any more; the URL is absolute).
router.post(
  "/cows",
  authMiddleware,
  authorizeRoles("CEO", "DAIRY_MANAGER", "VET"),
  (req, res, next) => {
    cowImageUpload.single("image")(req, res, async (err) => {
      if (err) return next(err);
      if (!req.file) {
        return res
          .status(400)
          .json({ error: "No image file uploaded (field name: image)" });
      }
      try {
        const result = await uploadBufferToCloudinary(req.file.buffer, {
          folder: "mwirigi/cows",
        });
        res.status(201).json({
          success: true,
          message: "Image uploaded",
          data: {
            imageUrl: result.secure_url,
            publicId: result.public_id, // useful for future delete/replace
            width: result.width,
            height: result.height,
            bytes: result.bytes,
            format: result.format,
          },
        });
      } catch (uploadErr) {
        next(uploadErr);
      }
    });
  },
);

// Local error handler — turns multer + Cloudinary errors into a 400 with
// a readable message.
router.use((err, _req, res, _next) => {
  if (err) {
    return res.status(400).json({ error: err.message });
  }
  res.status(500).json({ error: "Unknown upload error" });
});

export default router;

// =====================================================================
// LEGACY: disk-storage handler. Kept as a comment per migration request.
// Restore by uncommenting and reverting the matching legacy block in
// upload.middleware.js + the express.static line in app.js.
// =====================================================================
//
// import { cowImagePublicPath } from "../../middleware/upload.middleware.js";
//
// router.post(
//   "/cows",
//   authMiddleware,
//   authorizeRoles("CEO", "DAIRY_MANAGER", "VET"),
//   (req, res, next) => {
//     cowImageUpload.single("image")(req, res, (err) => {
//       if (err) return next(err);
//       if (!req.file) {
//         return res
//           .status(400)
//           .json({ error: "No image file uploaded (field name: image)" });
//       }
//       const imageUrl = cowImagePublicPath(req.file.filename);
//       res.status(201).json({
//         success: true,
//         message: "Image uploaded",
//         data: { imageUrl, size: req.file.size, mime: req.file.mimetype },
//       });
//     });
//   },
// );

import express from "express";
import {
  authMiddleware,
  authorizeRoles,
} from "../../middleware/auth.middleware.js";
import {
  cowImageUpload,
  cowImagePublicPath,
} from "../../middleware/upload.middleware.js";

const router = express.Router();

// POST /api/uploads/cows
//
// Accepts a single file under the form field `image`. Returns
// { imageUrl } — a relative path the frontend prefixes with API_BASE.
//
// Errors are funneled through the generic err handler at the bottom
// (multer surfaces fileFilter / fileSize errors via `next(err)`).
router.post(
  "/cows",
  authMiddleware,
  authorizeRoles("CEO", "DAIRY_MANAGER", "VET"),
  (req, res, next) => {
    cowImageUpload.single("image")(req, res, (err) => {
      if (err) return next(err);
      if (!req.file) {
        return res
          .status(400)
          .json({ error: "No image file uploaded (field name: image)" });
      }
      const imageUrl = cowImagePublicPath(req.file.filename);
      res.status(201).json({
        success: true,
        message: "Image uploaded",
        data: { imageUrl, size: req.file.size, mime: req.file.mimetype },
      });
    });
  },
);

// Local error handler — turns multer's MulterError + our fileFilter
// rejections into a 400 with a readable message.
router.use((err, _req, res, _next) => {
  if (err) {
    return res.status(400).json({ error: err.message });
  }
  res.status(500).json({ error: "Unknown upload error" });
});

export default router;

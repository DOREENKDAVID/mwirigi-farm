export const validate = (schema) => (req, res, next) => {
  try {
    const parsed = schema.parse(req.body);
    req.body = parsed; // replace with clean data
    next();
  } catch (err) {
    return res.status(400).json({
      message: "Validation error",
      errors: err.errors,
    });
  }
};
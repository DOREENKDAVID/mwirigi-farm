import * as service from "./reminders.service.js";

export const list = async (req, res) => {
  try {
    const unit = typeof req.query.unit === "string" ? req.query.unit : null;
    const status = typeof req.query.status === "string" ? req.query.status : null;
    res.json(await service.listReminders({ unit, status }));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const kpis = async (_req, res) => {
  try {
    res.json(await service.getKpis());
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Synthetic ids embed colons (e.g. "vaccine:abc:next-due"). Express
// preserves them inside a single :param, but we use the wildcard form
// `/:syntheticId(*)` on routes that need it. Here we rely on the
// `req.params.syntheticId` being passed verbatim from the URL.
export const markDone = async (req, res) => {
  try {
    const id = req.params.syntheticId;
    if (!id) return res.status(400).json({ error: "syntheticId required" });
    const userId = req.user?.id ?? null;
    const row = await service.markDone(id, userId);
    res.json({ success: true, override: row });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const snooze = async (req, res) => {
  try {
    const id = req.params.syntheticId;
    const days = Number(req.body?.days ?? 1);
    if (!id) return res.status(400).json({ error: "syntheticId required" });
    const row = await service.snooze(id, days);
    res.json({ success: true, override: row });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

export const undo = async (req, res) => {
  try {
    const id = req.params.syntheticId;
    if (!id) return res.status(400).json({ error: "syntheticId required" });
    await service.undo(id);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

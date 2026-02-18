(function() {
  "use strict";

  const scriptTag = document.currentScript;
  const appId = scriptTag.getAttribute("data-app-id");
  const appName = scriptTag.getAttribute("data-app-name");
  const userId = scriptTag.getAttribute("data-user-id");
  const userName = scriptTag.getAttribute("data-user-name");

  function csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.getAttribute("content") : "";
  }

  async function api(method, path, body) {
    const options = {
      method: method,
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken(),
      },
      credentials: "same-origin",
    };
    if (body !== undefined) {
      options.body = JSON.stringify(body);
    }
    const response = await fetch(path, options);
    if (response.status === 204) return null;
    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: response.statusText }));
      throw new Error(error.error || response.statusText);
    }
    return response.json();
  }

  const basePath = `/apps/${appId}`;

  const db = {
    async createTable(name, columns) {
      return api("POST", `${basePath}/tables`, { name, columns });
    },

    async listTables() {
      const result = await api("GET", `${basePath}/tables`);
      return result.tables;
    },

    async dropTable(name) {
      return api("DELETE", `${basePath}/tables/${encodeURIComponent(name)}`);
    },

    async query(table, options = {}) {
      const params = new URLSearchParams();
      if (options.limit) params.set("limit", options.limit);
      if (options.offset) params.set("offset", options.offset);
      if (options.where) {
        Object.entries(options.where).forEach(([k, v]) => {
          params.set(`where[${k}]`, v);
        });
      }
      const qs = params.toString();
      const result = await api("GET", `${basePath}/tables/${encodeURIComponent(table)}/rows${qs ? "?" + qs : ""}`);
      return result.rows;
    },

    async get(table, rowId) {
      const result = await api("GET", `${basePath}/tables/${encodeURIComponent(table)}/rows/${rowId}`);
      return result.row;
    },

    async insert(table, data) {
      return api("POST", `${basePath}/tables/${encodeURIComponent(table)}/rows`, { data });
    },

    async update(table, rowId, data) {
      return api("PATCH", `${basePath}/tables/${encodeURIComponent(table)}/rows/${rowId}`, { data });
    },

    async delete(table, rowId) {
      return api("DELETE", `${basePath}/tables/${encodeURIComponent(table)}/rows/${rowId}`);
    },
  };

  const KV_TABLE = "_kv_store";
  let kvInitialized = false;

  async function ensureKvTable() {
    if (kvInitialized) return;
    try {
      await db.createTable(KV_TABLE, [
        { name: "namespace", type: "TEXT" },
        { name: "key", type: "TEXT" },
        { name: "value", type: "TEXT" },
      ]);
    } catch (e) {
      // Table may already exist, that's fine
    }
    kvInitialized = true;
  }

  const kv = {
    async get(namespace, key) {
      await ensureKvTable();
      const rows = await db.query(KV_TABLE, { where: { namespace, key }, limit: 1 });
      if (rows.length === 0) return null;
      try {
        return JSON.parse(rows[0].value);
      } catch {
        return rows[0].value;
      }
    },

    async set(namespace, key, value) {
      await ensureKvTable();
      const jsonValue = JSON.stringify(value);
      const existing = await db.query(KV_TABLE, { where: { namespace, key }, limit: 1 });
      if (existing.length > 0) {
        return db.update(KV_TABLE, existing[0].id, { value: jsonValue });
      } else {
        return db.insert(KV_TABLE, { namespace, key, value: jsonValue });
      }
    },

    async list(namespace) {
      await ensureKvTable();
      const rows = await db.query(KV_TABLE, { where: { namespace }, limit: 1000 });
      return rows.map(r => {
        let val;
        try { val = JSON.parse(r.value); } catch { val = r.value; }
        return { key: r.key, value: val };
      });
    },

    async delete(namespace, key) {
      await ensureKvTable();
      const existing = await db.query(KV_TABLE, { where: { namespace, key }, limit: 1 });
      if (existing.length > 0) {
        return db.delete(KV_TABLE, existing[0].id);
      }
    },
  };

  const agent = {
    async ask(message) {
      // TODO: Wire up to agent conversation endpoint
      console.warn("AgentGridOS.agent.ask() is not yet implemented");
      return { error: "not_implemented" };
    },
  };

  window.AgentGridOS = {
    app: { id: parseInt(appId), name: appName },
    user: { id: parseInt(userId), name: userName },
    db,
    kv,
    agent,
  };
})();

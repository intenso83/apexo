migrate((app) => {
  const sessions = new Collection({
    type: "base",
    name: "intake_sessions",
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      {
        name: "created_by",
        type: "text",
        required: true,
        max: 64,
      },
      {
        name: "device_label",
        type: "text",
        max: 120,
      },
      {
        name: "expires_at",
        type: "date",
        required: true,
      },
      {
        name: "used",
        type: "bool",
      },
      {
        name: "used_at",
        type: "date",
      },
      {
        name: "cancelled",
        type: "bool",
      },
    ],
    indexes: [
      "CREATE INDEX idx_intake_sessions_created_by ON intake_sessions (created_by)",
      "CREATE INDEX idx_intake_sessions_expires_at ON intake_sessions (expires_at)",
    ],
  })
  app.save(sessions)

  const submissions = new Collection({
    type: "base",
    name: "intake_submissions",
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      {
        name: "session",
        type: "relation",
        required: true,
        maxSelect: 1,
        collectionId: sessions.id,
        cascadeDelete: true,
      },
      {
        name: "packet_json",
        type: "editor",
        required: true,
        maxSize: 131072,
        hidden: true,
      },
      {
        name: "status",
        type: "select",
        required: true,
        maxSelect: 1,
        values: ["pending", "imported", "rejected"],
      },
      {
        name: "received_at",
        type: "date",
        required: true,
      },
      {
        name: "reviewed_by",
        type: "text",
        max: 64,
      },
      {
        name: "reviewed_at",
        type: "date",
      },
      {
        name: "patient_id",
        type: "text",
        max: 64,
      },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_intake_submissions_session ON intake_submissions (session)",
      "CREATE INDEX idx_intake_submissions_status_received ON intake_submissions (status, received_at)",
    ],
  })
  app.save(submissions)
}, (app) => {
  try {
    app.delete(app.findCollectionByNameOrId("intake_submissions"))
  } catch (_) {
    // The collection is already absent.
  }
  try {
    app.delete(app.findCollectionByNameOrId("intake_sessions"))
  } catch (_) {
    // The collection is already absent.
  }
})

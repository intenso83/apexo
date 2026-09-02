// PocketBase serializes every route handler into an isolated JSVM program.
// Keep validation inside each handler instead of relying on shared closures.

routerAdd("POST", "/api/apexo/intake/sessions", (e) => {
  const maxBodyBytes = 4096
  const raw = toString(e.request.body)
  if (!raw || raw.length > maxBodyBytes) {
    throw new BadRequestError("Invalid intake request.")
  }
  let body
  try {
    body = JSON.parse(raw)
  } catch (_) {
    throw new BadRequestError("Invalid intake request.")
  }
  const deviceLabel = typeof body.device_label === "string"
    ? body.device_label.trim().slice(0, 120)
    : ""
  const active = e.app.findRecordsByFilter(
    "intake_sessions",
    "created_by = {:createdBy} && used = false && cancelled = false && expires_at > @now",
    "-expires_at",
    11,
    0,
    { createdBy: e.auth.id },
  )
  if (active.length >= 10) {
    throw new TooManyRequestsError("Too many active intake sessions. Wait for an existing session to expire.")
  }

  const collection = e.app.findCollectionByNameOrId("intake_sessions")
  const session = new Record(collection)
  session.set("created_by", e.auth.id)
  session.set("device_label", deviceLabel)
  session.set("expires_at", new Date(Date.now() + 30 * 60 * 1000).toISOString())
  e.app.save(session)

  return e.json(201, {
    session_id: session.id,
    expires_at: session.getDateTime("expires_at").string(),
  })
}, $apis.requireAuth("users", "_superusers"), $apis.bodyLimit(4096), $apis.skipSuccessActivityLog())

routerAdd("POST", "/api/apexo/intake/submit", (e) => {
  const maxPacketBytes = 128 * 1024
  const packetVersion = "practice-patient-intake-2026-09-02-v1"
  const questionnaireVersion = "practice-medical-history-2026-09-02-v1"
  const questionIds = [
    "allergies",
    "penicillin_allergy",
    "latex_allergy",
    "adverse_dental_reaction",
    "respiratory_disease",
    "asthma",
    "coagulation_disorder",
    "diabetes",
    "epilepsy",
    "artificial_joints",
    "glaucoma",
    "thyroid_disorder",
    "neurological_psychiatric_disorder",
    "infectious_disease",
    "liver_kidney_disease",
    "gastrointestinal_disorder",
    "rheumatism_arthritis",
    "cardiovascular_disease",
    "heart_failure",
    "myocardial_infarction",
    "endocarditis",
    "arrhythmia",
    "pacemaker_or_implanted_device",
    "blood_pressure_disorder",
    "stroke",
    "antibiotic_prophylaxis",
    "pregnancy",
    "recent_hospitalization",
    "ongoing_medical_treatment",
    "anticoagulant_antiplatelet_therapy",
    "other_medications",
    "chemotherapy_radiotherapy",
    "antiresorptive_therapy",
    "smoking",
    "alcohol_use",
  ]
  const answerValues = ["yes", "no", "unknown", "not_applicable"]
  const isShortText = (value, max) =>
    typeof value === "string" && value.trim().length > 0 && value.length <= max

  const raw = toString(e.request.body)
  if (!raw || raw.length > maxPacketBytes + 4096) {
    throw new BadRequestError("Invalid intake request.")
  }
  let body
  try {
    body = JSON.parse(raw)
  } catch (_) {
    throw new BadRequestError("Invalid intake request.")
  }
  const sessionId = typeof body.session_id === "string" ? body.session_id.trim() : ""
  if (!/^[A-Za-z0-9]{15}$/.test(sessionId)) {
    throw new BadRequestError("The intake session is invalid or expired. Please call a member of staff.")
  }

  const packet = body.packet
  if (!packet || typeof packet !== "object" || Array.isArray(packet)) {
    throw new BadRequestError("Invalid intake form.")
  }
  if (packet.packet_version !== packetVersion ||
      packet.questionnaire_version !== questionnaireVersion) {
    throw new BadRequestError("This intake form version is no longer accepted. Please call a member of staff.")
  }
  const personal = packet.personal
  if (!personal || typeof personal !== "object" ||
      !isShortText(personal.family_name, 200) ||
      !isShortText(personal.given_name, 200) ||
      !isShortText(personal.date_of_birth, 40)) {
    throw new BadRequestError("The required personal details are incomplete.")
  }
  const history = packet.medical_history
  const answers = history && history.answers
  if (!answers || typeof answers !== "object") {
    throw new BadRequestError("The medical history is incomplete.")
  }
  for (let i = 0; i < questionIds.length; i++) {
    const answer = answers[questionIds[i]]
    if (!answer || answerValues.indexOf(answer.value) < 0) {
      throw new BadRequestError("Every medical-history question must be answered.")
    }
    if (answer.notes !== undefined &&
        (typeof answer.notes !== "string" || answer.notes.length > 4000)) {
      throw new BadRequestError("A medical-history note is too long.")
    }
  }
  if (packet.patient_confirmed !== true ||
      !packet.signature ||
      !isShortText(packet.signature.name, 240)) {
    throw new BadRequestError("The intake form must be confirmed and signed.")
  }
  const packetJson = JSON.stringify(packet)
  if (!packetJson || packetJson.length > maxPacketBytes) {
    throw new BadRequestError("The intake form is too large.")
  }

  let receiptId = ""
  e.app.runInTransaction((txApp) => {
    let session
    try {
      session = txApp.findRecordById("intake_sessions", sessionId)
    } catch (_) {
      throw new BadRequestError("The intake session is invalid or expired. Please call a member of staff.")
    }
    if (session.getBool("used") ||
        session.getBool("cancelled") ||
        session.getDateTime("expires_at").unix() <= new DateTime().unix()) {
      throw new BadRequestError("The intake session is invalid or expired. Please call a member of staff.")
    }

    const collection = txApp.findCollectionByNameOrId("intake_submissions")
    const submission = new Record(collection)
    submission.set("session", session.id)
    submission.set("packet_json", packetJson)
    submission.set("status", "pending")
    submission.set("received_at", new Date().toISOString())
    txApp.save(submission)

    session.set("used", true)
    session.set("used_at", new Date().toISOString())
    txApp.save(session)
    receiptId = submission.id
  })

  return e.json(201, { receipt_id: receiptId })
}, $apis.requireGuestOnly(), $apis.bodyLimit(135168), $apis.skipSuccessActivityLog())

routerAdd("GET", "/api/apexo/intake/submissions", (e) => {
  const records = e.app.findRecordsByFilter(
    "intake_submissions",
    "status = 'pending'",
    "-received_at",
    100,
    0,
  )
  const result = records.map((record) => ({
    id: record.id,
    received_at: record.getDateTime("received_at").string(),
    packet: JSON.parse(record.getString("packet_json")),
  }))
  return e.json(200, { items: result })
}, $apis.requireAuth("users", "_superusers"), $apis.bodyLimit(0), $apis.skipSuccessActivityLog())

routerAdd("POST", "/api/apexo/intake/submissions/{id}/imported", (e) => {
  const raw = toString(e.request.body)
  if (!raw || raw.length > 4096) {
    throw new BadRequestError("Invalid review request.")
  }
  let body
  try {
    body = JSON.parse(raw)
  } catch (_) {
    throw new BadRequestError("Invalid review request.")
  }
  const patientId = typeof body.patient_id === "string" ? body.patient_id.trim() : ""
  if (!/^[A-Za-z0-9_-]{8,64}$/.test(patientId)) {
    throw new BadRequestError("A valid Apexo patient id is required.")
  }
  const record = e.app.findRecordById("intake_submissions", e.request.pathValue("id"))
  if (record.getString("status") !== "pending") {
    throw new BadRequestError("This intake submission has already been reviewed.")
  }
  record.set("status", "imported")
  record.set("patient_id", patientId)
  record.set("reviewed_by", e.auth.id)
  record.set("reviewed_at", new Date().toISOString())
  e.app.save(record)
  return e.json(200, { success: true })
}, $apis.requireAuth("users", "_superusers"), $apis.bodyLimit(4096), $apis.skipSuccessActivityLog())

routerAdd("POST", "/api/apexo/intake/submissions/{id}/rejected", (e) => {
  const record = e.app.findRecordById("intake_submissions", e.request.pathValue("id"))
  if (record.getString("status") !== "pending") {
    throw new BadRequestError("This intake submission has already been reviewed.")
  }
  record.set("status", "rejected")
  record.set("reviewed_by", e.auth.id)
  record.set("reviewed_at", new Date().toISOString())
  e.app.save(record)
  return e.json(200, { success: true })
}, $apis.requireAuth("users", "_superusers"), $apis.bodyLimit(0), $apis.skipSuccessActivityLog())

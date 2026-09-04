migrate((app) => {
  const collection = app.findCollectionByNameOrId("intake_submissions")
  collection.fields.add(new FileField({
    name: "intake_pdf",
    required: false,
    maxSelect: 1,
    maxSize: 2 * 1024 * 1024,
    mimeTypes: ["application/pdf"],
    protected: true,
  }))
  app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("intake_submissions")
  collection.fields.removeByName("intake_pdf")
  app.save(collection)
})

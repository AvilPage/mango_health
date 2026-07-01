/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  // ── steps + groups (no cross-references) ─────────────────────────────────
  app.importCollections([
    {
      "name": "steps",
      "type": "base",
      "listRule": "@request.auth.id != ''",
      "viewRule": "@request.auth.id != ''",
      "createRule": "@request.auth.id != ''",
      "updateRule": "@request.auth.id = user",
      "deleteRule": "@request.auth.id = user",
      "indexes": ["CREATE UNIQUE INDEX idx_steps_user_date ON steps (user, date)"],
      "fields": [
        { "name": "user",          "type": "relation", "required": true,  "collectionId": "_pb_users_auth_", "cascadeDelete": true,  "maxSelect": 1,  "hidden": false, "presentable": false, "system": false },
        { "name": "date",          "type": "text",     "required": true,  "hidden": false, "presentable": false, "system": false },
        { "name": "steps",         "type": "number",   "required": true,  "min": 0, "hidden": false, "presentable": false, "system": false },
        { "name": "reward_points", "type": "number",   "required": true,  "min": 0, "hidden": false, "presentable": false, "system": false }
      ]
    },
    {
      "name": "groups",
      "type": "base",
      "listRule": "@request.auth.id != ''",
      "viewRule": "@request.auth.id != ''",
      "createRule": "@request.auth.id != ''",
      "updateRule": "@request.auth.id = created_by",
      "deleteRule": "@request.auth.id = created_by",
      "indexes": ["CREATE UNIQUE INDEX idx_groups_invite_code ON groups (invite_code)"],
      "fields": [
        { "name": "name",        "type": "text",     "required": true,  "hidden": false, "presentable": true,  "system": false },
        { "name": "invite_code", "type": "text",     "required": true,  "hidden": false, "presentable": false, "system": false },
        { "name": "created_by",  "type": "relation", "required": true,  "collectionId": "_pb_users_auth_", "cascadeDelete": false, "maxSelect": 1, "hidden": false, "presentable": false, "system": false }
      ]
    }
  ], false);

  // ── group_members (references groups, created above) ─────────────────────
  const groupsCol = app.findCollectionByNameOrId("groups");
  app.importCollections([
    {
      "name": "group_members",
      "type": "base",
      "listRule": "@request.auth.id != ''",
      "viewRule": "@request.auth.id != ''",
      "createRule": "@request.auth.id != ''",
      "updateRule": null,
      "deleteRule": "@request.auth.id = user",
      "indexes": ["CREATE UNIQUE INDEX idx_group_members_unique ON group_members (\"group\", user)"],
      "fields": [
        { "name": "group", "type": "relation", "required": true,  "collectionId": groupsCol.id, "cascadeDelete": true,  "maxSelect": 1, "hidden": false, "presentable": false, "system": false },
        { "name": "user",  "type": "relation", "required": true,  "collectionId": "_pb_users_auth_", "cascadeDelete": true,  "maxSelect": 1, "hidden": false, "presentable": false, "system": false }
      ]
    }
  ], false);
}, (app) => {
  for (const name of ["group_members", "groups", "steps"]) {
    try { app.delete(app.findCollectionByNameOrId(name)); } catch (_) {}
  }
});

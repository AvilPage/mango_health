/// <reference path="../pb_data/types.d.ts" />

// Allow authenticated users to list/view other users (needed for member search).
migrate((app) => {
  const users = app.findCollectionByNameOrId("users");
  users.listRule = "@request.auth.id != ''";
  users.viewRule = "@request.auth.id != ''";
  app.save(users);
}, (app) => {
  const users = app.findCollectionByNameOrId("users");
  users.listRule = "id = @request.auth.id";
  users.viewRule = "id = @request.auth.id";
  app.save(users);
});

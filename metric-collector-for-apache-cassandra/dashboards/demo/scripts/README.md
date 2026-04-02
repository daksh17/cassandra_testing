# MongoDB scripts

## Create a sharded database and collection

Use after the sharded cluster exists (e.g. created by Terraform). Run against the cluster’s **mongos** (Atlas connection string already uses mongos).

```bash
# From this repo root, with Atlas connection string:
mongosh "mongodb+srv://<user>:<password>@<cluster>.mongodb.net/?retryWrites=true" \
  --file scripts/create-sharded-db.js
```

**Custom DB, collection, and shard key:**

```bash
DB_NAME=my_db \
COLLECTION_NAME=my_coll \
SHARD_KEY_FIELD=user_id \
SHARD_KEY_HASHED=true \
  mongosh "<connection-uri>" --file scripts/create-sharded-db.js
```

- `SHARD_KEY_HASHED=true` (default): use a hashed shard key for even distribution.
- `SHARD_KEY_HASHED=false`: use ascending key (e.g. `{ _id: 1 }`) for range queries on the shard key.

Then check with `sh.status()` in mongosh.

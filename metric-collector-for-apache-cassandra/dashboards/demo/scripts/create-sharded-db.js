/**
 * Create a sharded database with one sharded collection.
 *
 * Run against a SHARDED cluster (e.g. Atlas connection string or mongos):
 *   mongosh "<connection-uri>" --file scripts/create-sharded-db.js
 *
 * Or with env vars (set DB_NAME, COLLECTION_NAME, SHARD_KEY_FIELD before running):
 *   DB_NAME=my_app_db COLLECTION_NAME=events SHARD_KEY_FIELD=_id mongosh "..." --file scripts/create-sharded-db.js
 *
 * Defaults: db my_app_db, collection events, shard key { _id: "hashed" }.
 */

const dbName = process.env.DB_NAME || 'my_app_db';
const collectionName = process.env.COLLECTION_NAME || 'events';
// Shard key field; use "hashed" for value to get hashed shard key (good for high write throughput)
const shardKeyField = process.env.SHARD_KEY_FIELD || '_id';
const shardKeyIsHashed = (process.env.SHARD_KEY_HASHED || 'true').toLowerCase() === 'true';

// Enable sharding on the database
const enableResult = sh.enableSharding(dbName);
if (!enableResult.ok) {
  throw new Error('enableSharding failed: ' + JSON.stringify(enableResult));
}
print('Sharding enabled on database: ' + dbName);

// Build shard key spec: { field: 1 } or { field: "hashed" }
const shardKey = {};
shardKey[shardKeyField] = shardKeyIsHashed ? 'hashed' : 1;

const shardResult = sh.shardCollection(dbName + '.' + collectionName, shardKey);
if (!shardResult.ok) {
  throw new Error('shardCollection failed: ' + JSON.stringify(shardResult));
}
print('Collection sharded: ' + dbName + '.' + collectionName + ' with key: ' + JSON.stringify(shardKey));

// Optional: create the collection if it doesn't exist (shardCollection creates it, but we can add a validator or options)
// db.getSiblingDB(dbName).createCollection(collectionName);

print('Done. Verify with: sh.status()');

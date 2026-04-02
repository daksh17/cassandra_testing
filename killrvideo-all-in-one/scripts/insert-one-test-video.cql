-- Insert one test video so the KillrVideo UI shows something.
-- Run in DataStax Studio (http://localhost:9091), connection host = dse, port = 9042.
--
-- If you get "Unknown identifier" or "Invalid column", run:
--   DESCRIBE TABLE killrvideo.videos;
--   DESCRIBE TABLE killrvideo.latest_videos;
-- and adjust column names to match (e.g. video_id vs videoid).

USE killrvideo;

-- Step 1: Get a user ID (Generator creates users; we need one).
-- Run this and note one userid value (e.g. a550e840-e29b-41d4-a716-446655440000).
SELECT userid, firstname, lastname FROM users LIMIT 5;

-- Step 2: Insert one video. Replace 0ce5c553-5caf-48f8-8e68-3c06b05e24d2 with a real userid from Step 1.
-- Using a fixed videoid so we can reuse it in latest_videos (Cassandra UUID literal).
INSERT INTO videos (videoid, userid, name, description, location, location_type, preview_image_location, tags, added_date)
VALUES (
  a1b2c3d4-e5f6-4789-a012-3456789abcde,
  0ce5c553-5caf-48f8-8e68-3c06b05e24d2,
  'Test Video',
  'Inserted manually so the UI shows something.',
  'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
  0,
  'https://img.youtube.com/vi/dQw4w9WgXcQ/default.jpg',
  {'test', 'manual'},
  toTimestamp(now())
);

-- Step 3: Insert into latest_videos so "Latest" on the UI shows this video.
-- Replace 0ce5c553-5caf-48f8-8e68-3c06b05e24d2 with the same userid. Use today's date as yyyymmdd (e.g. 20260311).
-- If the table has a "bucket" column, add it (e.g. 0) to the column list and values.
INSERT INTO latest_videos (yyyymmdd, added_date, videoid, userid, name, preview_image_location)
VALUES (
  '20260311',
  toTimestamp(now()),
  a1b2c3d4-e5f6-4789-a012-3456789abcde,
  0ce5c553-5caf-48f8-8e68-3c06b05e24d2,
  'Test Video',
  'https://img.youtube.com/vi/dQw4w9WgXcQ/default.jpg'
);

-- Then refresh http://localhost:3000 and check Latest.

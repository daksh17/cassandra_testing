-- Optional: sample rows for compaction lab (run after ensure-compaction-lab.cql).
-- TWCS: rows share a partition (sensor + day) with increasing timestamps.
-- LCS: random UUID keys (spread across token ranges).

USE demo_hub;

INSERT INTO lab_twcs_sensor (sensor_id, day, event_ts, val, payload)
VALUES ('sensor-a', '2026-04-02', '2026-04-02T10:00:00.000+0000', 1.0, 'twcs-sample-1');

INSERT INTO lab_twcs_sensor (sensor_id, day, event_ts, val, payload)
VALUES ('sensor-a', '2026-04-02', '2026-04-02T10:05:00.000+0000', 2.0, 'twcs-sample-2');

INSERT INTO lab_twcs_sensor (sensor_id, day, event_ts, val, payload)
VALUES ('sensor-a', '2026-04-02', '2026-04-02T14:30:00.000+0000', 3.0, 'twcs-sample-3');

-- Fixed UUIDs for repeatable demos (LCS).
INSERT INTO lab_lcs_lookup (id, body, created_at)
VALUES (11111111-1111-1111-1111-111111111111, 'lcs-row-1', currenttimestamp());

INSERT INTO lab_lcs_lookup (id, body, created_at)
VALUES (22222222-2222-2222-2222-222222222222, 'lcs-row-2', currenttimestamp());

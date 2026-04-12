-- TWCS fixed at 2-minute windows; gc_grace_seconds varies (30 / 60 / 90 / 120) for tombstone / repair semantics.
-- Apply: ./cassandra/apply-twcs-gc-lab.sh
-- Load:  python3 cassandra/load_twcs_gc_lab.py --help  (from host against 127.0.0.1:19442)

CREATE KEYSPACE IF NOT EXISTS demo_hub
  WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

-- Partition (sensor_id, day) + clustering event_ts ASC — insert in time order for TWCS.

CREATE TABLE IF NOT EXISTS demo_hub.lab_twcs_w2m_gc30 (
  sensor_id text,
  day text,
  event_ts timestamp,
  val double,
  payload text,
  PRIMARY KEY ((sensor_id, day), event_ts)
) WITH CLUSTERING ORDER BY (event_ts ASC)
  AND compaction = {
    'class': 'TimeWindowCompactionStrategy',
    'compaction_window_unit': 'MINUTES',
    'compaction_window_size': '2'
  }
  AND gc_grace_seconds = 30
  AND default_time_to_live = 0;

CREATE TABLE IF NOT EXISTS demo_hub.lab_twcs_w2m_gc60 (
  sensor_id text,
  day text,
  event_ts timestamp,
  val double,
  payload text,
  PRIMARY KEY ((sensor_id, day), event_ts)
) WITH CLUSTERING ORDER BY (event_ts ASC)
  AND compaction = {
    'class': 'TimeWindowCompactionStrategy',
    'compaction_window_unit': 'MINUTES',
    'compaction_window_size': '2'
  }
  AND gc_grace_seconds = 60
  AND default_time_to_live = 0;

CREATE TABLE IF NOT EXISTS demo_hub.lab_twcs_w2m_gc90 (
  sensor_id text,
  day text,
  event_ts timestamp,
  val double,
  payload text,
  PRIMARY KEY ((sensor_id, day), event_ts)
) WITH CLUSTERING ORDER BY (event_ts ASC)
  AND compaction = {
    'class': 'TimeWindowCompactionStrategy',
    'compaction_window_unit': 'MINUTES',
    'compaction_window_size': '2'
  }
  AND gc_grace_seconds = 90
  AND default_time_to_live = 0;

CREATE TABLE IF NOT EXISTS demo_hub.lab_twcs_w2m_gc120 (
  sensor_id text,
  day text,
  event_ts timestamp,
  val double,
  payload text,
  PRIMARY KEY ((sensor_id, day), event_ts)
) WITH CLUSTERING ORDER BY (event_ts ASC)
  AND compaction = {
    'class': 'TimeWindowCompactionStrategy',
    'compaction_window_unit': 'MINUTES',
    'compaction_window_size': '2'
  }
  AND gc_grace_seconds = 120
  AND default_time_to_live = 0;

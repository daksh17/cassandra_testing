-- Lab tables to compare TimeWindowCompactionStrategy (TWCS) vs LeveledCompactionStrategy (LCS).
-- Keyspace matches hub demo (SimpleStrategy RF=1). Apply: ./cassandra/apply-compaction-lab.sh
--
-- TWCS: best for time-series where writes arrive roughly in insert order within each partition.
--       Partition = (sensor_id, day) so each partition is one day bucket; clustering = event_ts ASC.
-- LCS:  better for read-heavy, overwrite-heavy, or uniformly distributed keys; more SSTable levels.

CREATE KEYSPACE IF NOT EXISTS demo_hub
  WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};

-- Time-window compaction: 4-hour windows (easy to see multiple windows under load testing).
CREATE TABLE IF NOT EXISTS demo_hub.lab_twcs_sensor (
  sensor_id text,
  day text,
  event_ts timestamp,
  val double,
  payload text,
  PRIMARY KEY ((sensor_id, day), event_ts)
) WITH CLUSTERING ORDER BY (event_ts ASC)
  AND compaction = {
    'class': 'TimeWindowCompactionStrategy',
    'compaction_window_unit': 'HOURS',
    'compaction_window_size': '4'
  }
  AND default_time_to_live = 0;

-- Leveled compaction: point lookups by id; SSTables organized in levels.
CREATE TABLE IF NOT EXISTS demo_hub.lab_lcs_lookup (
  id uuid PRIMARY KEY,
  body text,
  created_at timestamp
) WITH compaction = {
    'class': 'LeveledCompactionStrategy',
    'sstable_size_in_mb': '160'
};

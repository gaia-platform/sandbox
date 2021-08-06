---------------------------------------------
-- Copyright (c) Gaia Platform LLC
-- All rights reserved.
---------------------------------------------

create table if not exists session (
      id string,
      agent_id string,
      current_project_id string,
      is_active bool,
      last_session_timestamp uint64,
      last_agent_timestamp uint64,
      created_timestamp uint64
);

create table if not exists activity (
      activity_type string,
      id string,
      timestamp uint64,
      references session
);

create table if not exists project (
      id string,
      path string,
      name string,
      ddl string,
      ruleset string,
      output string,
      references session
);

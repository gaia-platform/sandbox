---------------------------------------------
-- Copyright (c) Gaia Platform LLC
-- All rights reserved.
---------------------------------------------

create table if not exists project (
      session_id string,
      name string,
      ddl_file string,
      ruleset_file string,
      output string
);

create table if not exists session (
      session_id string,
      agent_id string,
      is_active bool,
      last_session_timestamp uint64,
      last_agent_timestamp uint64,
      created_timestamp uint64,
      references project
);

create table if not exists activity (
      type uint8,
      action uint8,
      payload string,
      timestamp uint64,
      references session,
      references project
);

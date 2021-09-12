---------------------------------------------
-- Copyright (c) Gaia Platform LLC
-- All rights reserved.
---------------------------------------------

database coordinator

table project (
    name string,
    ddl_file string,
    ruleset_file string,
    output string,
    session references session,
    active_session references session
        using current_project
)

table session (
    session_id string,
    agent_id string,
    is_active bool,
    last_session_timestamp uint64,
    last_agent_timestamp uint64,
    created_timestamp uint64,
    projects references project[],
    current_project references project,
    activities references activity[]
)

create table if not exists activity (
    type uint8,
    action uint8,
    payload string,
    timestamp uint64,
    session references session
);

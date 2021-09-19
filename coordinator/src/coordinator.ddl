---------------------------------------------
-- Copyright (c) Gaia Platform LLC
-- All rights reserved.
---------------------------------------------

database coordinator

table session (
    session_id string unique,
    agent_id string,
    is_active bool,
    last_session_timestamp uint64,
    last_agent_timestamp uint64,
    created_timestamp uint64,
    current_project_name string,
    projects references project[],
    browser_activities references browser_activity[],
    agent_activities references agent_activity[],
    project_activities references project_activity[],
    editor_file_requests references editor_file_request[],
    editor_contents references editor_content[]
)

table project (
    name string,
    version string,
    session references session,
    project_files references project_file[]
)

table project_file (
    name string,
    content string,
    project references project,
    editor_contents references editor_content[]
)

table browser_activity (
    timestamp uint64,
    session references session
)

table agent_activity (
    timestamp uint64,
    agent_id string,
    session references session
)

table project_activity (
    name string,
    timestamp uint64,
    session references session
)

table editor_file_request (
    name string,
    timestamp uint64,
    session references session
)

table editor_content (
    timestamp uint64,
    project_file references project_file,
    session references session
)

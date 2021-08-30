/////////////////////////////////////////////
// Copyright (c) Gaia Platform LLC
// All rights reserved.
/////////////////////////////////////////////

#include <unistd.h>

#include <algorithm>
#include <string>

#include "enums.hpp"

namespace enums
{
    namespace activity_type
    {
        e_activity_type to_activity_type(const std::string &activity_type)
        {
            if (activity_type == "browser")
            {
                return e_activity_type::browser;
            }
            else if (activity_type == "agent")
            {
                return e_activity_type::agent;
            }
            else if (activity_type == "project")
            {
                return e_activity_type::project;
            }
            else if (activity_type == "editor")
            {
                return e_activity_type::editor;
            }

            return e_activity_type::undefined;
        }
    }

    namespace action
    {
        e_action to_action(const std::string &action)
        {
            if (action == "connected")
            {
                return e_action::connected;
            }
            else if (action == "select")
            {
                return e_action::select;
            }
            else if (action == "exit")
            {
                return e_action::exit;
            }
            else if (action == "ddl")
            {
                return e_action::ddl_file;
            }
            else if (action == "ruleset")
            {
                return e_action::ruleset_file;
            }

            return e_action::undefined;
        }
    }
}

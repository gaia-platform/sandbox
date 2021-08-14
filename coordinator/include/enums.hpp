#pragma once

namespace enums
{
    namespace activity_type
    {
        enum e_activity_type : uint8_t
        {
            undefined,
            browser,
            agent,
            project
        };

        e_activity_type to_activity_type(const std::string &activity_type);
    }

    namespace action
    {
        enum e_action : uint8_t
        {
            undefined,
            connected,
            select,
            exit
        };

        e_action to_action(const std::string &action);
    }
}
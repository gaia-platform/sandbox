/////////////////////////////////////////////
// Copyright (c) Gaia Platform LLC
// All rights reserved.
/////////////////////////////////////////////

#include "utils.hpp"

#include <chrono>
#include <ctime>

#include <aws/crt/UUID.h>

using namespace std::chrono;

namespace gaia
{
namespace coordinator
{
namespace utils
{

uint64_t get_time_millis()
{
    return duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count();
}

uint64_t get_time_seconds()
{
    return static_cast<uint64_t>(time(nullptr));
}

std::string trim_to_size(const std::string& string)
{
    if (string.length() <= 100)
    {
        return string;
    }
    else
    {
        return string.substr(0, 100) + "...";
    }
}

std::string get_uuid()
{
    return Aws::Crt::UUID().ToString().c_str();
}

} // namespace utils
} // namespace coordinator
} // namespace gaia

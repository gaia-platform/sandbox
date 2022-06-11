////////////////////////////////////////////////////
// Copyright (c) Gaia Platform Authors
//
// Use of this source code is governed by the MIT
// license that can be found in the LICENSE.txt file
// or at https://opensource.org/licenses/MIT.
////////////////////////////////////////////////////

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

constexpr size_t c_max_topic_log_length = 100;

uint64_t current_time_millis()
{
    return duration_cast<milliseconds>(system_clock::now().time_since_epoch()).count();
}

uint64_t current_time_seconds()
{
    return static_cast<uint64_t>(time(nullptr));
}

std::string trim_to_size(const std::string& string)
{
    if (string.length() <= c_max_topic_log_length)
    {
        return string;
    }
    else
    {
        return string.substr(0, c_max_topic_log_length) + "...";
    }
}

std::string get_uuid()
{
    return Aws::Crt::UUID().ToString().c_str();
}

} // namespace utils
} // namespace coordinator
} // namespace gaia

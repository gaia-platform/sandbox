/////////////////////////////////////////////
// Copyright (c) Gaia Platform LLC
// All rights reserved.
/////////////////////////////////////////////

#pragma once

#include <string>

namespace gaia
{
namespace coordinator
{
namespace utils
{

uint64_t current_time_millis();

uint64_t current_time_seconds();

std::string trim_to_size(const std::string& string);

std::string get_uuid();

} // namespace utils
} // namespace coordinator
} // namespace gaia

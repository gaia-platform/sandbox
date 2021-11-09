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

uint64_t get_time_millis();

uint64_t get_time_seconds();

std::string trim_to_size(const std::string& string);

std::string get_uuid();


void create_fake_metrics();

} // namespace utils
} // namespace coordinator
} // namespace gaia

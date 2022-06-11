////////////////////////////////////////////////////
// Copyright (c) Gaia Platform Authors
//
// Use of this source code is governed by the MIT
// license that can be found in the LICENSE.txt file
// or at https://opensource.org/licenses/MIT.
////////////////////////////////////////////////////

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

// This file is part of libmumble.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file at the root of the
// Mumble source tree or at <https://www.mumble.info/LICENSE>.

#ifndef MUMBLE_EXAMPLESERVER_ENDPOINTS_HPP
#define MUMBLE_EXAMPLESERVER_ENDPOINTS_HPP

#include "mumble/Endpoint.hpp"

#include <unordered_set>

using Endpoint  = mumble::Endpoint;
using Endpoints = std::unordered_set< Endpoint >;

#endif

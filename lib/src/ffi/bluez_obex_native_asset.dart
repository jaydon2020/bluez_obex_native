/*
 * Copyright (c) 2026 Jian De Seak jiande2020@gmail.com. All rights reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import 'dart:ffi';

@Native<Void Function(Pointer<Void>)>(symbol: 'bluez_obex_init')
external void bundledObexInit(Pointer<Void> data);

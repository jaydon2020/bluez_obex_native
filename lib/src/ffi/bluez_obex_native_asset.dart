/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import 'dart:ffi';

@Native<Void Function(Pointer<Void>)>(symbol: 'bluez_obex_init')
external void bundledObexInit(Pointer<Void> data);

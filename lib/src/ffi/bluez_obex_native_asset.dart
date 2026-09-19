/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

// Asset-id anchor for the native build hook.
//
// `hook/build.dart` emits libbluez_obex_native.so as a CodeAsset whose name
// points at this file. The bindings currently load it through
// `lib/src/internal/library_loader.dart`.
library;

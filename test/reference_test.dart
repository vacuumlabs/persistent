// Copyright (c) 2014, VaccumLabs.
// Copyright (c) 2012, Google Inc. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// Authors are listed in the AUTHORS file

library reference_test;

import 'package:vacuum_persistent/persistent.dart';
import 'package:unittest/unittest.dart';
import 'dart:async';

main() {
  run();
}

run() {
  test('Creation of Reference', () {
    var r = new Reference();
    expect(r.deref(), null);
    r = new Reference(10);
    expect(r.deref(), 10);
  });

  test('Changing value of ref', () {
    var r = new Reference(15);
    r.update((_) => 20);
    expect(r.deref(), 20);
    r.update((_) => 30);
    expect(r.deref(), 30);
  });

  test('After change of value notification come.', () {
    var r = new Reference(10);
    expect(r.onChange.first, completion(per({'oldVal': 10, 'newVal': 15})));
    r.update((_)=> 15);
  });

  test('After change of value notification come.', () {
    var r = new Reference(10);
    expect(r.onChangeSync.first, completion(per({'oldVal': 10, 'newVal': 15})));
    r.update((_) => 15);
    expect(r.onChangeSync.first, completion(per({'oldVal': 15, 'newVal': 20})));
    r.update((_) => 20);
  });
}

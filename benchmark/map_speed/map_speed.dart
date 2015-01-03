// Copyright (c) 2014, VacuumLabs.
// Copyright (c) 2012, Google Inc. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// Authors are listed in the AUTHORS file

library map_bench;

import 'package:vacuum_persistent/persistent.dart';
import 'package:benchmark_harness/benchmark_harness.dart';
import 'dart:math';

part 'benchmarks.dart';
part 'interface.dart';
part 'interface_impl.dart';

Map interfaces = {
  "PersistentMap": () => new PersistentMapInterface(),
  "TransientMap": () => new TransientMapInterface(),
  "Map": () => new StandardMapInterface(),
};

var sizes = [{1000:6, 2000: 3, 3000: 2, 6000: 1}];
int times = 10;

void main() {
  var config =
  {
    'Write': ((sample, factory) => (new WriteBenchmark(sample, factory))),
    'Read': ((sample, factory) => (new ReadBenchmark(sample, factory))),
  };
  var result = {};
  config.forEach((mode, creator){
    for (Map sample in sizes) {
      var res = {};
      var dev = {};
      interfaces.forEach((k,v){
        res[k] = 0;
        dev[k] = 0;
      });
      for (int i=0; i<times; i++){
        for (String name in interfaces.keys) {
          var meas = creator(sample, interfaces[name]).measure();
          res[name] += meas;
          dev[name] += meas*meas;
        }
      }
      for (String name in interfaces.keys) {
        res[name] /= times;
        dev[name] /= times;
        dev[name] = sqrt(dev[name] - res[name] * res[name]);
      }
      for (String name in interfaces.keys) {
        var _dev = 2*(res[name]*dev['Map']+res['Map']*dev[name])/res['Map']/res['Map']/sqrt(times);
        print('${mode} ${name} sample ${sample}: ${res[name]/res['Map']} '+
              '+- ${_dev} (${res[name]} us)');
      }
    }
  });
}

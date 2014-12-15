// Copyright (c) 2014, VaccumLabs.
// Copyright (c) 2012, Google Inc. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// Authors are listed in the AUTHORS file

library map_test;

import 'package:vacuum_persistent/persistent.dart';
import 'package:unittest/unittest.dart';

main() {
  run();
}

run() {

  group('Structure test', () {
    test('Simple structure', () {
      PersistentMap pm = new PersistentMap();
      pm = pm.assoc(0,0);
      pm = pm.assoc(32,32);
      pm = pm.assoc(2,2);
      pm = pm.assoc(3,3);
      pm = pm.assoc(35,35);
      TransientMap tm = pm.asTransient();

      tm.doAssoc(2,10);

      DumpNodeMap nodeTm = new DumpNodeMap(tm.getRootForTesting);
      DumpNodeMap nodePm = new DumpNodeMap(pm.getRootForTesting);

      expect(nodeTm[0].isIdenticalTo(nodePm[0]), isTrue);
      // 2 should be new
      expect(nodeTm[2].isIdenticalTo(nodePm[2]), isFalse);
      expect(nodeTm[3].isIdenticalTo(nodePm[3]), isTrue);

      tm.doAssoc(2,15);
      // Transient root shouldn't change now
      expect(nodeTm.isIdenticalTo(new DumpNodeMap(tm.getRootForTesting)), isTrue);

      // Persistent root should change and copy references
      pm = pm.assoc(2,10);
      expect(nodePm.isIdenticalTo(new DumpNodeMap(pm.getRootForTesting)), isFalse);
    });

    test('More complicated insert', () {
      // 1059%32 = 3
      PersistentMap pm = new PersistentMap.fromMap({0:0,1:1,2:2,32:32,35:35,3:3,1059:1059});
      DumpNodeMap psNode = new DumpNodeMap(pm.getRootForTesting);
      TransientMap tm = pm.asTransient();
       // No changes yet, should be identical
      expect(new DumpNodeMap(tm.getRootForTesting).isIdenticalTo(psNode), isTrue);
      tm.doAssoc(1315,1315);
      // 1315 (dec) = 10100100011 (bin)
      DumpNodeMap tsNode = new DumpNodeMap(tm.getRootForTesting);
       // Transient root should be copied
      expect(tsNode.isIdenticalTo(psNode), isFalse);
      expect(tsNode[0].isIdenticalTo(psNode[0]), isTrue);
      expect(tsNode[1].isIdenticalTo(psNode[1]), isTrue);
      expect(tsNode[2].isIdenticalTo(psNode[2]), isTrue);
      // Node on 3rd branch should be copied, because 1315%32 = 3
      expect(tsNode[3].isIdenticalTo(psNode[3]), isFalse);

      // References to nodes on 3rd branch in ps should be copied
      for (int i = 0; i < psNode[3].numNodes; i++) {
        expect(tsNode[3][i].isIdenticalTo(psNode[3][i]), isTrue);
      }

      // In case you would like too see the structure of the Persistent map with node pm
//      print(testDumpMap(pm.getRootForTesting));

      // New node should be added to ts
      expect(tsNode[3].numNodes, equals(psNode[3].numNodes + 1));
    });
  });

  group('Persistent map', () {
    test('assoc', () {
      PersistentMap pm = new PersistentMap();
      pm = pm.assoc('a', 'b');
      expect(pm.toMap(), equals({'a': 'b'}));

      pm = pm.assoc('a', 'c');
      expect(pm.toMap(), equals({'a': 'c'}));

    });

    test('get', () {
      PersistentMap pm = new PersistentMap();
      pm = pm.assoc('a', 'b');
      pm = pm.assoc('b', 'c');

      expect(pm.get('a'), equals('b'));
      expect(() => pm.get('c'), throws);
      expect(pm.get('c','none'), equals('none'));
    });

    test('update', () {
      PersistentMap pm = new PersistentMap();
      pm = pm.assoc('a', 'b');

      expect(pm.update('a', (a) => '$a b').toMap(), equals({'a': 'b b'}));
      expect(() => pm.update('c', (a) => '$a b'), throws);
      expect(pm.update('c', ([a = 'new value']) => '$a b').toMap(), equals({'a': 'b', 'c': 'new value b'}));
    });

    test('delete', () {
      PersistentMap pm = new PersistentMap();
      pm = pm.assoc('a', 'b');

      expect(pm.delete('a').toMap(), equals({}));
      expect(() => pm.delete('b'), throws);
      expect(pm.delete('b', missingOk: true).toMap(), equals({'a': 'b'}));
    });

    test('forEachKeyValue', () {
      PersistentMap pm = new PersistentMap();
      pm = pm.assoc('a', 'b');
      pm = pm.assoc('c', 'b');

      String res = '';
      pm.forEachKeyValue((k,v) => res = '${res}${k}${v},');

      expect(res, equals('ab,cb,'));
    });

    test('mapValues', () {
      PersistentMap pm = new PersistentMap();
      pm = pm.assoc('a', 'b');
      pm = pm.assoc('c', 'b');

      String res = '';
      pm = pm.mapValues((v) => '$v a');

      expect(pm.toMap(), equals({'a': 'b a', 'c': 'b a'}));
    });

    test('intersection', () {
      var m1 = new PersistentMap.fromMap({'a':1, 'b':2});
      var m2 = new PersistentMap.fromMap({'c':4, 'b':3});
      var i1 = m1.intersection(m2).toMap();
      var i2 = m1.intersection(m2, (x,y)=>x+y).toMap();
      expect(i1, equals({'b':3}));
      expect(i2, equals({'b':5}));
    });

    test('union', () {
      var m1 = new PersistentMap.fromMap({'a':1, 'b':2});
      var m2 = new PersistentMap.fromMap({'c':4, 'b':3});
      var u1 = m1.union(m2).toMap();
      var u2 = m1.union(m2, (x,y)=>x+y).toMap();
      expect(u1, equals({'b':3, 'a':1, 'c':4}));
      expect(u2, equals({'b':5, 'a':1, 'c':4}));
    });
  });

  group('Transient map', () {
    test('insert', () {
      TransientMap tm = new TransientMap();
      tm.doAssoc('a', 'b');
      expect(tm.toMap(), equals({'a': 'b'}));

      tm.doAssoc('a', 'c');
      expect(tm.toMap(), equals({'a': 'c'}));
    });

    test('get', () {
      TransientMap tm = new TransientMap();
      tm.doAssoc('a', 'b');
      tm.doAssoc('b', 'c');

      expect(tm.get('a'), equals('b'));
      expect(() => tm.get('c'), throws);
      expect(tm.get('c', 'none'), equals('none'));
    });

    test('update', () {
      TransientMap tm = new TransientMap();
      tm.doAssoc('a', 'b');

      expect(tm.doUpdate('a', (a) => '$a b').toMap(), equals({'a': 'b b'}));
      expect(() => tm.doUpdate('c', (a) => '$a b'), throws);
    });

    test('delete', () {
      TransientMap tm = new TransientMap();
      tm.doAssoc('a', 'b');
      tm.doAssoc('b', 'b');

      expect(tm.doDelete('a').toMap(), equals({'b': 'b'}));
      expect(() => tm.doDelete('c'), throws);
      expect(tm.doDelete('c', missingOk: true).toMap(), equals({'b': 'b'}));
    });

    test('forEachKeyValue', () {
      TransientMap tm = new TransientMap();
      tm.doAssoc('a', 'b');
      tm.doAssoc('c', 'b');

      String res = '';
      tm.forEachKeyValue((k,v) => res = '${res}${k}${v},');

      expect(res, equals('ab,cb,'));
    });

    test('mapValues', () {
      TransientMap tm = new TransientMap();
      tm.doAssoc('a', 'b');
      tm.doAssoc('c', 'b');

      String res = '';
      tm.doMapValues((v) => '$v a');

      expect(tm.toMap(), equals({'a': 'b a', 'c': 'b a'}));
    });
  });

  group('Persistent+Transient map', () {

      test('lookup', (){
        PersistentMap map = new PersistentMap();
        map = map.assoc('key1', 'val1');
        for (var _map in [map, map.asTransient()]) {
          expect(_map.get('key1'), equals('val1'));
          expect(() => _map.get('key2'), throws);
        }
      });

      test('containsKey', () {
        PersistentMap map = new PersistentMap();
        map = map.assoc('key1', 'val1');
        map = map.assoc('key2', 'val2');
        map = map.assoc('key3', 'val3');
        expect(map.containsKey('key1'), isTrue);
        expect(map.containsKey('key2'), isTrue);
        expect(map.containsKey('key22'), isFalse);
        TransientMap trans = map.asTransient();
        trans['key4'] = 'val4';
        expect(trans.containsKey('key1'), isTrue);
        expect(trans.containsKey('key2'), isTrue);
        expect(trans.containsKey('key4'), isTrue);
        expect(trans.containsKey('key22'), isFalse);

      });

    });

  group('deep persistent data', () {
    test('insertIn', () {
      PersistentMap map = new PersistentMap();
      map = map.assoc('a', new PersistentMap());
      PersistentMap map2 = insertIn(map, ['a', 'b'], 'c');

      expect(map2 == per({'a': {'b': 'c'}}), isTrue);
      expect(map == map2, isFalse);
      expect(map, equals(per({'a': {}})));
    });

    test('deleteIn', () {
      PersistentMap map = new PersistentMap();
      map = map.assoc('a', new PersistentMap());
      map = insertIn(map, ['a', 'b'], 'c');
      PersistentMap map2 = deleteIn(map, ['a', 'b']);

      expect(map2['a'], equals(new PersistentMap.fromMap({})));
      expect(map == map2, isFalse);
      expect(map, equals(new PersistentMap.fromMap({'a': new PersistentMap.fromMap({'b': 'c'})})));
    });

    test('lookupIn', () {
      PersistentMap map = new PersistentMap();
      map = map.assoc('a', new PersistentMap());
      map = insertIn(map, ['a', 'b'], 'c');

      expect(lookupIn(map, ['a', 'b']), equals('c'));
    });
  });
}

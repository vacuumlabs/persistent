// Copyright (c) 2014, VacuumLabs.
// Copyright (c) 2012, Google Inc. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// Authors are listed in the AUTHORS file

part of persistent;

/**
 * All the persistent structures implements this.
 */
class Persistent {}

class _Owner {}

/**
 * Converts structure of [List]s and [Map]s to the equivalent
 * persistent structure.
 *
 * Works recursively.
 */
persist(from) {
  if(from is Persistent) return from;
  if(from is Map) {
    var map = new PersistentMap();
    return map.withTransient((TransientMap map) {
      from.forEach((key,value) => map.doAssoc(per(key), per(value)));
    });
  }
  else if (from is Set) {
    from = from.map((e) => persist(e));
    return new PersistentSet.from(from);
  }
  else if(from is Iterable) {
    from = from.map((e) => persist(e));
    return new PersistentVector.from(from);
  }
  else {
    return from;
  }
}

/// Alias for [persist]
per(from) => persist(from);

class None{
  const None();
}

const _none = const None();
final _getNone = () => _none;
bool _isNone(val) => val == _none;

/**
 * Looks up the element given by the [path] of keys and indices
 * in the [structure] of Maps and Vectors.
 *
 * If the [path] does not exist, [orElse] is called to obtain the
 * return value. Default [orElse] throws exception.
 */
lookupIn(Persistent structure, List path, {notFound}) =>
    _lookupIn(structure, path.iterator, notFound: notFound);

_lookupIn(dynamic s, Iterator path, {notFound}) {
  if(!path.moveNext()) return s;
  if(s is PersistentMap) {
    return _lookupIn(s.get(path.current, notFound), path, notFound: notFound);
  }
  else if(s is PersistentVector) {
    return _lookupIn(s.get(path.current, notFound), path, notFound: notFound);
  }
  else if(s is TransientMap) {
    return _lookupIn(s.get(path.current, notFound), path, notFound: notFound);
  }
  else if(s is TransientVector) {
    return _lookupIn(s.get(path.current, notFound), path, notFound: notFound);
  }
  else {
    throw new Exception('This should not happen');
  }
}

/**
 * Inserts the [value] to the position given by the [path] of keys and indices
 * in the [structure] of Maps and Vectors.
 *
 * This will not create any middleway structures.
 */
Persistent insertIn(Persistent structure, Iterable path, dynamic value) =>
    _insertIn(structure, path.iterator..moveNext(), value);

Persistent _insertIn(s, Iterator path, dynamic value) {
  var current = path.current;
  if(path.moveNext()) { //path continues
    if(s is PersistentMap) {
      return s.assoc(current, _insertIn(s.get(current), path, value));
    }
    else if(s is PersistentVector) {
      return s.set(current, _insertIn(s.get(current), path, value));
    }
    else if(s is TransientMap) {
      return s.doAssoc(current, _insertIn(s.get(current), path, value));
    }
    else if(s is TransientVector) {
      return s.doSet(current, _insertIn(s.get(current), path, value));
    }
    else {
      throw new Exception('This should not happen');
    }
  }
  else {
    if(s is PersistentMap) {
      return s.assoc(current, value);
    }
    else if(s is PersistentVector) {
      if(current == s.length) {
        return s.push(value);
      }
      return s.set(current, value);
    }
    else if(s is TransientMap) {
      return s.doAssoc(current, value);
    }
    else if(s is TransientVector) {
      if(current == s.length) {
        return s.doPush(value);
      }
      return s.doSet(current, value);
    }
    else {
      throw new Exception('This should not happen');
    }
  }
}

/**
 * Removes the element given by the [path] of keys and indices
 * in the [structure] of Maps and Vectors.
 *
 * If the [path] does not exist and [safe] is not `true`, exception is thrown.
 * If the [path] does not exist and [safe] is specified as `true`,
 * the same map is returned.
 */
Persistent deleteIn(Persistent structure, List path, {bool safe: false}) =>
    _deleteIn(structure, path.iterator..moveNext(), safe: safe);

Persistent _deleteIn(s, Iterator path, {bool safe: false}) {
  var current = path.current;
  if(path.moveNext()) { //path continues
    if(s is PersistentMap) {
      var deleted = _deleteIn(s.get(current), path, safe: safe);
      return s.assoc(current, deleted);
    }
    else if(s is PersistentVector) {
      var deleted = _deleteIn(s.get(current), path, safe: safe);
      return s.set(current, deleted);
    }
    else if(s is TransientMap) {
      var deleted = _deleteIn(s.get(current), path, safe: safe);
      return s.doAssoc(current, deleted);
    }
    else if(s is TransientVector) {
      var deleted = _deleteIn(s.get(current), path, safe: safe);
      return s.doSet(current, deleted);  }
    else {
      throw new Exception('This should not happen');
    }
  }
  else {
    if(s is PersistentMap) {
      return s.delete(current);
    }
    else if(s is PersistentVector) {
      if(s.length - 1 == current) return s.pop();
      else throw new Exception('Cannot delete non last element in PersistentVector');
    }
    else if(s is TransientMap) {
      return s.doDelete(current);
    }
    else if(s is TransientVector) {
      if(s.length - 1 == current) return s.doPop();
      else throw new Exception('Cannot delete non last element in TransientVector');
    }
    else {
      throw new Exception('This should not happen');
    }
  }
  return throw 'It cant get here...';
}

abstract class DumpNodeMap {

  factory DumpNodeMap(_ANodeBase node) => new _DumpNodeMapImpl(node);

  operator[](int key);

  get numNodes;

  get values;

  get isLeaf;

  isIdenticalTo(DumpNodeMap other);

}

class NilNodeMap implements DumpNodeMap {

  _throw() => throw new Exception("Non-existent node");

  operator[](int key) => _throw();
  get numNodes => _throw();
  get values => _throw();
  get isLeaf => _throw();
  isIdenticalTo(DumpNodeMap other) => _throw();
}

class _DumpNodeMapImpl implements DumpNodeMap {
  _ANodeBase node;

  factory _DumpNodeMapImpl(_ANodeBase node) => new _DumpNodeMapImpl.fromNode(node);

  _DumpNodeMapImpl.fromNode(_ANodeBase this.node);

  get numNodes {
    if ((node is _EmptyMap) || (node is _Leaf)) return 0;
    assert(node is _SubMap);
    return _SubMap._popcount((node as _SubMap)._bitmap);
  }

  DumpNodeMap operator [](int key) {
    if ((key < 0) || (key > 31)) throw new RangeError.range(key, 0, 31);
    if ((node as _SubMap)._bitmap & (1 << key) == 0) return new NilNodeMap();
    int compressedIndex = _SubMap._popcount((node as _SubMap)._bitmap & ((1 << key) - 1));
    return new DumpNodeMap((node as _SubMap)._array[compressedIndex]);
  }

  get values {
    if ((node is _EmptyMap) || (node is _SubMap)) throw new Exception("${node.runtimeType} has no values");
    assert(node is _Leaf);
    return (node as _Leaf)._pairs.map((f) => f.second == null ? f.first : "<${f.first},${f.second}>");
  }

  get isLeaf => node is _Leaf;

  isIdenticalTo(_DumpNodeMapImpl other) => identical(node, other.node);
}

class DumpNum {

  int _hash;
  dynamic value;

  DumpNum(this.value, [hash = null]) {
    if (hash == null) _hash = value;
    else _hash = hash;
  }

  @override
  get hashCode => _hash;

  set hashCode(int h) => _hash = hashCode;

  toString() => "$value";

}

testDumpStructure(_ANodeBase _node) {

  dump(DumpNodeMap node) {
    if (node.isLeaf) return node.values;
    Map structure = {};
    for (int i = 0; i < 32; i++) {
      if (node[i] is! NilNodeMap) structure[i] = dump(node[i]);
    }
    return structure;
  }

  return dump(new DumpNodeMap(_node));

}

testDumpVector(_VNode _node) {

  dump(DumpNodeVector node) {
    Map structure = {};
    for (int i = 0; i < node.numNodes; i++) {
      structure[i] = node[i] is DumpNodeVector ? dump(node[i]) : node[i];
    }
    return structure;
  }

  return dump(new DumpNodeVector(_node));

}

abstract class DumpNodeVectorGeneral {

  isIdenticalTo(DumpNodeVectorGeneral other);

  get data;
}

abstract class DumpNodeVector implements DumpNodeVectorGeneral{

  factory DumpNodeVector(_VNode node) => new _DumpNodeVectorImpl(node);

  operator[](int key);

  get numNodes;

  isIdenticalTo(DumpNodeVector other);

}

class _DumpNodeVectorData implements DumpNodeVectorGeneral {

  var _data;
  get data => _data;

  _DumpNodeVectorData(this._data);

  isIdenticalTo(DumpNodeVectorGeneral other) => other is DumpNodeVector ? false : identical(data, other.data);

  toString() => "$_data";
}

class _DumpNodeVectorImpl implements DumpNodeVector {

  _VNode node;
  get data => node;

  _DumpNodeVectorImpl(this.node);

  operator[](int key) => node._array[key] is _VNode ? new _DumpNodeVectorImpl(node._array[key])
      : new _DumpNodeVectorData(node._array[key]);

  get numNodes => node._array.length;

  isIdenticalTo(_DumpNodeVectorImpl other) => identical(this.node, other.node);

}

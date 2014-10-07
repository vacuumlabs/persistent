// Copyright (c) 2014, VacuumLabs.
// Copyright (c) 2012, Google Inc. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// Authors are listed in the AUTHORS file

part of persistent;

/**
 * A base class for implementations of [ReadSet].
 */
abstract class _ReadSetBase<E>
    extends IterableBase<E>
    implements ReadSet<E> {

  String toString() {
    StringBuffer buffer = new StringBuffer('{');
    bool comma = false;
    this.forEach((E e) {
      if (comma) buffer.write(', ');
      buffer.write(e.toString());
      comma = true;
    });
    buffer.write('}');
    return buffer.toString();
  }
}

abstract class _PersistentSetMixim<E>
    implements PersistentSet<E> {

  PersistentSet<E> union(PersistentSet<E> persistentSet) =>
      this.withTransient((set)=>
        persistentSet.where((e) => !this.contains(e)).forEach((e)=>
            set.doInsert(e)
        )
      );

  PersistentSet<E> operator +(PersistentSet<E> persistentSet) =>
      union(persistentSet);

  PersistentSet<E> difference(PersistentSet<E> persistentSet) =>
      new PersistentSet.from(this.where((e) => !persistentSet.contains(e)));

  PersistentSet<E> operator -(PersistentSet<E> persistentSet) =>
      difference(persistentSet);

  Iterable<Pair> cartesianProduct(PersistentSet<E> persistentSet) =>
      this.expand((a) => persistentSet.map((b) => new Pair(a,b)));

  Iterable<Pair> operator *(PersistentSet persistentSet) =>
      cartesianProduct(persistentSet);

  PersistentSet<E> intersect(PersistentSet<E> persistentSet) =>
      new PersistentSet.from(this.where((e) => persistentSet.contains(e)));

  PersistentSet strictMap(f(E element)) =>
      new PersistentSet.from(this.map(f));

  PersistentSet<E> strictWhere(bool f(E element)) =>
      new PersistentSet<E>.from(this.where(f));
}

abstract class _SetImplBase<E> extends _ReadSetBase<E> {
  ReadMap<E, Null> get _map;

  bool contains(E element) => _map.containsKey(element);

  bool hasKey(E key) => contains(key);

  E get(E element, [E notFound = _none]) =>
      contains(element) ?
        element
      :
        notFound == _none ?
          _ThrowKeyError(element)
        :
          notFound;

  void forEach(f(E element)) => _map.forEachKeyValue((E k, v) => f(k));

  Iterable map(f(E element)) {
    return _map.map((pair)=>f(pair.first));
  }

  int get length => _map.length;

  bool operator ==(other) =>
      other is _SetImplBase ? _map == other._map : false;

  Iterator<E> get iterator =>
      _map.map((Pair<E, Object> pair) => pair.first).iterator;

  // PersistentMap's "last" is optimized
  E get last => _map.last.first;

  // PersistentMap's "elementAt" is optimized
  E elementAt(int index) => _map.elementAt(index).first;

  get test_get_root => _map.test_get_root;
}


class _PersistentSetImpl<E>
    extends _SetImplBase<E>
    with _PersistentSetMixim<E> {

  final PersistentMap<E, Null> _map;

  _PersistentSetImpl._internal(this._map);

  factory _PersistentSetImpl() =>
      new _PersistentSetImpl._internal(new PersistentMap<E, Object>());

  _PersistentSetImpl<E> insert(E element) =>
      new _PersistentSetImpl._internal(_map.assoc(element, null));

  _PersistentSetImpl<E> delete(E element, {bool allowMissing:false}) =>
      new _PersistentSetImpl._internal(_map.delete(element, allowMissing:allowMissing));

  TransientSet asTransient() {
    return new _TransientSetImpl._internal(_map.asTransient());
  }


  PersistentSet<E> union(PersistentSet<E> persistentSet){
    if(persistentSet is _PersistentSetImpl<E>){
      return new _PersistentSetImpl._internal(
          _map.union(persistentSet._map));
    } else {
      return super.union(persistentSet);
    }
  }

  PersistentSet<E> intersection(PersistentSet<E> persistentSet){
    if(persistentSet is _PersistentSetImpl<E>){
      return new _PersistentSetImpl._internal(
          _map.intersection(persistentSet._map));
    } else {
      return super.intersection(persistentSet);
    }
  }

  PersistentSet withTransient(void change(TransientSet set)) {
    TransientSet result = this.asTransient();
    change(result);
    return result.asPersistent();
  }

  bool operator==(other) =>
      other is ReadSet ?
        other is TransientSet ?
          this.length == other.length &&
          this.fold(true, (test, v)=> test && other.contains(v))
        :
          super == other
      :
        false;

  int get hashCode => this._map.hashCode;
}

class _TransientSetImpl<E> extends _SetImplBase<E> implements TransientSet<E> {
  final TransientMap<E, Null> _map;

  _TransientSetImpl._internal(this._map);

  factory _TransientSetImpl() =>
      new _TransientSetImpl._internal(new TransientMap<E, Object>());

  void doInsert(E element){
    _map.doAssoc(element, null);
  }

  void doDelete(E element, {bool allowMissing:false}){
    _map.doDelete(element, allowMissing:allowMissing);
  }

  PersistentSet asPersistent() {
    return new _PersistentSetImpl._internal(_map.asPersistent());
  }

}



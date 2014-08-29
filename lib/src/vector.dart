part of persistent;

const int _SHIFT = 5;
const int _SIZE = 1 << _SHIFT;
const int _MASK = _SIZE - 1;
var _NOT_SET;

getNotSet() {
  if (_NOT_SET == null)
    _NOT_SET = {};
  return _NOT_SET;
}

// Wrapper for referencing bool values
class Bool {
  bool value = false;
}

class Owner {}

abstract class PersistentVector<E> implements Iterable<E> {
  E get(int index, {Function orElse: null});
  E operator[](int index);
  PersistentVector<E> set(int index, E value);

  PersistentVector<E> push(E value);
  PersistentVector<E> pop();
  TransientVector<E> asMutable();

  E get first;
  E get last;

  factory PersistentVector() => new PersistentVectorImpl.empty();
  factory PersistentVector.from(Iterable<E> values) => new PersistentVectorImpl.from(values);
  PersistentVector<E> withMutations(void fn(TransientVector<E> vect));

  bool operator==(other);
  int get hashCode;
}

abstract class TransientVector<E> implements Iterable<E> {
  E get(int index, {Function orElse: null});
  E operator[](int index);
  void operator []=(int index, E value);
  void doSet(int index, E value);
  void doPush(E value);
  void doPop();
  PersistentVector<E> asImmutable();

  E get first;
  E get last;
}

abstract class PersistentVectorBase<E> extends IterableBase<E> {
  int _size;

  E _get(int index, {Function orElse: null});
  Option<E> _getOption(int index);

  E get first => _get(0);
  E get last => _get(this.length > 0 ? this.length - 1 : 0);
  int get length => _size;
  Iterator<E> get iterator => new VectorIterator<E>(this);
}

class VectorIterator<E> extends Iterator<E> {
  PersistentVectorBase<E> _parentVector;
  int _position = -1;
  int _length;

  VectorIterator(this._parentVector) {
    _length = _parentVector.length;
  }

  bool moveNext() {
    if (_length == _position + 1) return false;
    _position++;
    return true;
  }

  E get current => _parentVector._get(_position);
}

abstract class BaseVectorImpl<E> extends PersistentVectorBase<E> {
  int _origin;
  Owner __ownerID;
  VNode _root;
  VNode _tail;
  int _level;
  // cached hashCode.
  int _hashCode = null;
  bool __altered = false;

  BaseVectorImpl._prototype() {
    this._origin = 0;
    this.__ownerID = null;
    this._root = new VNode([], __ownerID);
    this._tail = _root;
    this._level = _SHIFT;
    this._size = 0;
  }

  E _get(int index, {Function orElse: null}) {
    try {
      index = _checkIndex(index);
    } catch(e) {
      if (orElse == null) {
        throw(e);
      } else {
        return orElse();
      }
    }

    var node = _vectorNodeFor(index);
    var maskedIndex = index & _MASK;
    // if resize ever gets publicly exposed, we need to check if node != null
    return node._get(maskedIndex);
  }

  Option<E> _getOption(int index) => new Option.fromNullable(_get(index));

  BaseVectorImpl<E> _set(int index, E value) {
    index = _checkIndex(index);
    if (index >= this.length) {
      if (value == getNotSet())
        return this;
      return this._withMutations((vect) => vect._resize(index+1)._set(index,value));
    }

    var vector = this;
    var newTail = vector._tail;
    var newRoot = vector._root;
    var didAlter = new Bool();
    if (index >= _getTailOffset(vector._size)) {
      newTail = _updateVNode(newTail, vector.__ownerID, 0, index, value, didAlter);
    } else {
      newRoot = _updateVNode(newRoot, vector.__ownerID, vector._level, index, value, didAlter);
    }
    if (!didAlter.value) {
      return vector;
    }
    if (vector.__ownerID != null) {
      vector._root = newRoot;
      vector._tail = newTail;
      vector.__altered = true;
      return vector;
    }
    return new PersistentVectorImpl._make(vector._origin, vector._size, vector._level, newRoot, newTail);
  }

  BaseVectorImpl<E> _push(E value) {
    var len = this.length;
    return this._withMutations((vect) => vect._resize(len+1)._set(len, value));
  }

  BaseVectorImpl<E> _pushAll(List<E> values) {
    var t = this._resize(this.length + values.length);
    for (int i = 0; i < values.length; i++) {
      t = t.set(this.length+i, values[i]);
    }
    return t;
  }

  BaseVectorImpl<E> _pop() {
    return this._resize(this.length-1);
  }

  int _getTailOffset(int size) {
    return size < _SIZE ? 0 : (((size - 1) >> _SHIFT) << _SHIFT);
  }

  int _checkIndex(int index) {
    if (index < 0 || index >= _size) {
      throw new RangeError.value(index);
    }
    return index;
  }

  VNode _vectorNodeFor(int index) {
    if (index >= _getTailOffset(this._size)) {
      return this._tail;
    }
    if (index < 1 << (this._level + _SHIFT)) {
      var node = this._root;
      var level = this._level;
      while (node != null && level > 0) {
        node = node._get((index >> level) & _MASK);
        level -= _SHIFT;
      }
      return node;
    }
    return null;
  }

  BaseVectorImpl<E> _resize(int end) {
    if (end < 0) {
      throw new RangeError.value(end);
    }
    var owner;
    if (__ownerID == null) {
      owner = __ownerID;
    } else {
      owner = new Owner();
    }
    //var owner = __ownerID || new Owner();
    var oldSize = _size;
    var newSize = end;

    if (oldSize == newSize) return this;
    var newLevel = _level;
    var newRoot = _root;

    var oldTailOffset = _getTailOffset(oldSize);
    var newTailOffset = _getTailOffset(newSize);
    while (newTailOffset >= 1 << (newLevel + _SHIFT)) {
      newRoot = new VNode(newRoot != null && newRoot.length > 0 ? [newRoot] : [], owner);
      newLevel += _SHIFT;
    }

    var oldTail = _tail;
    var newTail = newTailOffset < oldTailOffset ?
      _vectorNodeFor(newSize - 1) :
        newTailOffset > oldTailOffset ? new VNode([], owner) : oldTail;

    if (newTailOffset > oldTailOffset && oldSize > 0 && oldTail.length > 0) {
      newRoot = newRoot._ensureOwner(owner);
      var node = newRoot;
      for (var level = newLevel; level > _SHIFT; level -= _SHIFT) {
        var idx = (oldTailOffset >> level) & _MASK;
        node._set(idx , node._get(idx) == null ? node._get(idx)._ensureOwner(owner) : new VNode([], owner));
        node = node._get(idx);
      }
      node._set((oldTailOffset >> _SHIFT) & _MASK, oldTail);
    }

    if (newSize < oldSize) {
      newTail = newTail._removeAfter(owner, 0, newSize);
    }

    if (__ownerID != null) {
      _size = newSize;
      _origin = 0;
      _level = newLevel;
      _root = newRoot;
      _tail = newTail;
      __altered = true;
      return this;
    }
    return new PersistentVectorImpl._make(0, newSize, newLevel, newRoot, newTail);

  }

  // TODO: debug funkcia, umazat
  void printInfo() {
    print("Size: $_size");
    print("Origin: $_origin");
    print("Level: $_level");
    print("Root: $_root");
    print("Tail: $_tail");
  }

  BaseVectorImpl _ensureOwner(Owner ownerID) {
    if (ownerID == this.__ownerID) {
      return this;
    }
    if (ownerID == null) {
      this.__ownerID = ownerID;
      return new PersistentVectorImpl._make(this._origin, this._size, this._level, this._root, this._tail);
    }
    return new TransientVectorImpl._make(this._origin, this._size, this._level, this._root, this._tail, ownerID);
  }

  TransientVectorImpl _asMutable() {
    return this.__ownerID != null ? this : this._ensureOwner(new Owner());
  }

  PersistentVectorImpl _asImmutable() {
    return this._ensureOwner(null);
  }

  BaseVectorImpl _withMutations(fn) {
    var mutable = this._asMutable();
    fn(mutable);
    return mutable.wasAltered() ? mutable._ensureOwner(this.__ownerID) : this;
  }

}

class VNode {
  List _array;
  Owner _ownerID;

  int get length => _array.length;

  String toString() {
    return "VNode: " + _array.toString();
  }

  VNode(this._array, this._ownerID);

  void _set(int index, value) {
    if (_array.length > index) {
      _array[index] = value;
    } else {
      for (int i = _array.length; i < index; i++) {
        _array.add(null);
      }
      _array.add(value);
    }
  }

  _get(int index) => (index >= 0 && index < this.length) ? this._array[index] : null;

  VNode _removeAfter(Owner ownerID, int level, int index) {
    if ((index == (level > 0 ? 1 << level : 0 ))|| this.length == 0) {
      return this;
    }
    var sizeIndex = ((index - 1) >> level) & _MASK;
    if (sizeIndex >= this.length) {
      return this;
    }
    var removingLast = sizeIndex == this.length - 1;
    var newChild;
    if (level > 0) {
      var oldChild = this._array[sizeIndex];
      if (oldChild == null) newChild = null;
      else {
        newChild = oldChild.removeAfter(ownerID, level - _SHIFT, index);
      }
      if (newChild == oldChild && removingLast) {
        return this;
      }
    }
    if (removingLast && newChild == null) {
      return this;
    }
    var editable = _mutableVNode(this, ownerID);
    if (!removingLast) {
      editable._array.removeRange(sizeIndex + 1, editable._array.length);
    }
    if (newChild != null) {
      editable._array[sizeIndex] = newChild;
    }
    return editable;

  }

  _ensureOwner(ownerID) {
    if (ownerID != null && ownerID == _ownerID)
      return this;
    return new VNode(_array.sublist(0), ownerID);
  }

  VNode _update(ownerID, level, index, value, Bool didAlter) {
    var deleted = value == _NOT_SET;
    var node = this;
    var newNode;
    var idx = (index >> level) & _MASK;
    var nodeHas = node != null && idx < node._array.length;
    if (deleted && !nodeHas) {
      return node;
    }
    if (level > 0) {
      var lowerNode;
      if (node != null && node._array.length > idx) {
        lowerNode = node._array[idx];
      } else {
        lowerNode = null;
      }
      var newLowerNode = _updateVNode(lowerNode, ownerID, level - _SHIFT, index, value, didAlter);
      if (newLowerNode == lowerNode) {
        return node;
      }
      var newNode = _mutableVNode(node, ownerID);
      newNode._set(idx, newLowerNode);
      return newNode;
    }

    if (!deleted && nodeHas && node._array[idx] == value) {
      return node;
    }

    didAlter.value = true;

    newNode = _mutableVNode(node, ownerID);
    if (deleted) {
      newNode._set(idx, null);
    } else {
      newNode._set(idx, value);
    }
    return newNode;
  }
}

_updateVNode(VNode node, Owner ownerID, int level, int index, value, Bool didAlter) {
  if (node == null) {
    var t = new VNode([], new Owner());
    return t._update(ownerID, level, index, value, didAlter);
  }
  return node._update(ownerID, level, index, value, didAlter);
}

VNode _mutableVNode(VNode node, Owner ownerID) {
  if (ownerID != null && node != null && ownerID == node._ownerID) {
    return node;
  }
  return new VNode(node != null ? node._array.sublist(0) : [], ownerID);
}

class PersistentVectorImpl<E> extends BaseVectorImpl<E> implements PersistentVector<E> {
  factory PersistentVectorImpl.from(Iterable<E> values) {
    if (values.length == 0) {
      return new PersistentVectorImpl.empty();
    }
    PersistentVectorImpl<E> result = new PersistentVectorImpl.empty();
    result = result.withMutations((vector) {
      values.forEach((E value) {
        vector.doPush(value);
      });
      return vector;
    });
    return result;
  }

  factory PersistentVectorImpl.empty() => new PersistentVectorImpl._prototype();
  PersistentVectorImpl._prototype() : super._prototype();

  factory PersistentVectorImpl._make(int origin, int size, int level, VNode root, VNode tail) {
    var x = new PersistentVectorImpl._prototype();
    x._origin = origin;
    x._size = size;
    x._level = level;
    x._root = root;
    x._tail = tail;
    x.__ownerID = null;
    return x;
  }

  int get hashCode {
    if (this._hashCode == null) {
      int result = 17;
      for (E value in this) {
        result = 37 * result + value.hashCode % 1000000009;
      }
      this._hashCode = result;
    }
    return this._hashCode;
  }

  bool operator==(other) {
    if (other is! PersistentVectorImpl) return false;
    PersistentVectorImpl otherVector = other;
    if (this.hashCode != otherVector.hashCode) return false;
    if (this.length != otherVector.length) return false;
    for (int i = 0; i < this.length; i++) {
      if (this._get(i) != otherVector.get(i)) return false;
    }
    return true;
  }

  PersistentVectorImpl _clear() {
    if (this.length == 0) {
      return this;
    }
    return new PersistentVectorImpl.empty();
  }

  TransientVectorImpl asMutable() => _asMutable();
  PersistentVectorImpl withMutations(fn) => _withMutations(fn);
  PersistentVectorImpl push(E value) => _push(value);
  PersistentVectorImpl pop() => _pop();
  PersistentVectorImpl set(int index, E value) => _set(index, value);
  E get(int index, {Function orElse: null}) => _get(index, orElse: orElse);
  E operator[](int index) => _get(index);
}

class TransientVectorImpl<E> extends BaseVectorImpl<E> implements TransientVector<E> {
  TransientVectorImpl._prototype() : super._prototype();

  factory TransientVectorImpl._make(int origin, int size, int level, VNode root, VNode tail, Owner ownerID) {
    var x = new TransientVectorImpl._prototype();
    x._origin = origin;
    x._size = size;
    x._level = level;
    x._root = root;
    x._tail = tail;
    x.__ownerID = ownerID;
    return x;
  }

  bool wasAltered() {
    return this.__altered;
  }

  TransientVectorImpl _clear() {
    this._size = 0;
    this._origin = 0;
    this._level = _SHIFT;
    this._root = this._tail = null;
    this._hashCode = null;
    this.__altered = true;
    return this;
  }

  PersistentVectorImpl asImmutable() => _asImmutable();
  void doPush(E value) {
    _push(value);
  }
  void doPop() {
    _pop();
  }
  E get(int index, {Function orElse: null}) => _get(index, orElse: orElse);
  E operator[](int index) => _get(index);
  void doSet(int index, E value) {
    _set(index, value);
  }
  void operator []=(int index, E value) {
    _set(index, value);
  }
}
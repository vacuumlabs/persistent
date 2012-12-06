// Copyright (c) 2012, Google Inc. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// Author: Paul Brauner (polux@google.com)

part of persistent;

abstract class LList<A> {
  factory LList.nil() => new Nil<A>();
  factory LList.cons(A x, LList<A> xs) => new Cons<A>(x, xs);

  bool isNil();
  Cons<A> asCons();

  void foreach(f(A));
  // forall B, LList<B> map(B f(A))
  LList map(f(A));
  LList<A> filter(bool f(A));

  int length();
}

class LListBuilder<A> {
  LList<A> _first = null;
  Cons<A> _last = null;

  void add(A x) {
    Cons<A> cons = new Cons<A>(x, null);
    if (_first == null) {
      _first = cons;
    } else {
      _last.tail = cons;
    }
    _last = cons;
  }

  LList<A> build([tail = null]) {
    if (tail == null)
      tail = new Nil<A>();
    if (_first == null) {
      return tail;
    } else {
      _last.tail = tail;
      return _first;
    }
  }
}

abstract class LListBase<A> implements LList<A> {

  void foreach(f(A)) {
    LList<A> it = this;
    while (!it.isNil()) {
      Cons<A> cons = it.asCons();
      f(cons.elem);
      it = cons.tail;
    }
  }

  LList map(f(A)) {
    LListBuilder<A> builder = new LListBuilder<A>();
    LList<A> it = this;
    while (!it.isNil()) {
      Cons<A> cons = it.asCons();
      A elem = cons.elem;
      builder.add(f(elem));
      it = cons.tail;
    }
    return builder.build();
  }

  LList<A> filter(bool f(A)) {
    LListBuilder<A> builder = new LListBuilder<A>();
    LList<A> it = this;
    while (!it.isNil()) {
      Cons<A> cons = it.asCons();
      A elem = cons.elem;
      if (f(elem)) builder.add(elem);
      it = cons.tail;
    }
    return builder.build();
  }
}

class Nil<A> extends LListBase<A> {
  isNil() => true;
  asCons() { throw "Nil is not a Cons"; }
  toString() => "nil()";

  int length() => 0;
}

class Cons<A> extends LListBase<A> {
  int _length = null;

  final A elem;
  LList<A> tail;

  Cons(this.elem, this.tail);

  isNil() => false;
  asCons() => this;
  toString() => "cons($elem, $tail)";

  int length() {
    if (_length == null) {
      _length = tail.length() + 1;
    }
    return _length;
  }
}
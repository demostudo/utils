import 'dart:collection';
import 'dart:convert';

import '../converter_function.dart';
import '../event_sourcing.dart';

Iterable<DoubleLinkedQueueEntry<E>> _walkDoublyLinkedList<E>(
    DoubleLinkedQueueEntry<E> list) sync* {
  DoubleLinkedQueueEntry<E>? tail;
  for (DoubleLinkedQueueEntry<E>? cursor = list;
      cursor != null;
      cursor = cursor.previousEntry()) {
    tail = cursor;
  }
  for (var cursor = tail; cursor != null; cursor = cursor.nextEntry()) {
    yield cursor;
  }
}

/// An [Codec] which can [encode] and [decode] an
/// [DoublyLinkedEventSourcedModel].
class DoublyLinkedEventSourcedModelCodec<
        S extends EventSourcedSnapshot<S, B, E>,
        B extends EventSourcedSnapshotBuilder<S, B, E>,
        E extends UndoableEventSourcedEvent<S, B, E>>
    extends Codec<DoublyLinkedEventSourcedModel<S, B, E>,
        Map<String, dynamic>> {
  /// Create an [DoublyLinkedEventSourcedModelCodec].
  const DoublyLinkedEventSourcedModelCodec();

  @override
  Converter<Map<String, dynamic>, DoublyLinkedEventSourcedModel<S, B, E>>
      get decoder => ConverterFn((m) {
            final cursorI =
                ArgumentError.checkNotNull(m['cursorIndex'] as int?);
            final entries =
                ArgumentError.checkNotNull(m['entries'] as List?).cast<E>();
            DoubleLinkedQueueEntry<E>? cursor;
            DoubleLinkedQueueEntry<E> entry = _SentryDoubleLinkedQueueEntry();

            for (var i = 0; i < entries.length; i++) {
              final e = entries[i];
              entry.append(e);
              entry = entry.nextEntry()!;

              if (i == cursorI) {
                cursor = entry;
              }
            }

            return DoublyLinkedEventSourcedModel<S, B, E>._(
              initialState: ArgumentError.checkNotNull(m['initialState'] as S?),
              state: m['state'] as S,
              cursor: cursor ?? entry,
            );
          });

  @override
  Converter<DoublyLinkedEventSourcedModel<S, B, E>, Map<String, dynamic>>
      get encoder => ConverterFn((t) {
            final entries = <E>[];
            int? cursorI;
            var i = 0;
            for (final e in _walkDoublyLinkedList(t._eventCursor).skip(1)) {
              entries.add(e.element);
              if (e == t._eventCursor) {
                cursorI = i;
              }
              i++;
            }
            return <String, dynamic>{
              'initialState': t.initialState,
              'state': t._snapshot,
              'cursorIndex': cursorI,
              'entries': entries,
            };
          });
}

class _SentryDoubleLinkedQueueEntry<E> implements DoubleLinkedQueueEntry<E> {
  @override
  Never get element => throw Error();
  set element(E e) => throw Error();

  DoubleLinkedQueueEntry<E>? next;

  @override
  void append(E e) {
    if (next == null) {
      next = DoubleLinkedQueueEntry(e);
      return;
    }
    throw Error();
  }

  @override
  DoubleLinkedQueueEntry<E>? nextEntry() => next;

  @override
  void prepend(E e) => throw Error();

  @override
  DoubleLinkedQueueEntry<E>? previousEntry() => null;

  @override
  Never remove() => throw Error();
}

/// An [UndoableEventSourcedModel] which uses an [DoubleLinkedQueueEntry] as the
/// backing data structure.
class DoublyLinkedEventSourcedModel<
        S extends EventSourcedSnapshot<S, B, E>,
        B extends EventSourcedSnapshotBuilder<S, B, E>,
        E extends UndoableEventSourcedEvent<S, B, E>>
    extends UndoableEventSourcedModel<S, B, E> {
  /// Create an [DoublyLinkedEventSourcedModel].
  DoublyLinkedEventSourcedModel(S initialState)
      : _snapshot = initialState,
        super(initialState);

  DoublyLinkedEventSourcedModel._(
      {required S initialState,
      required S state,
      DoubleLinkedQueueEntry<E>? cursor})
      : _eventCursor = cursor ?? _SentryDoubleLinkedQueueEntry(),
        _snapshot = state,
        super(initialState);

  DoubleLinkedQueueEntry<E> _eventCursor = _SentryDoubleLinkedQueueEntry();
  @override
  bool canUndo() {
    // we are at the beggining, therefore there aren't any events, so we can't
    // undo
    if (_eventCursor.previousEntry() == null) {
      return false;
    }

    final previous = _eventCursor.previousEntry();
    assert(previous != null);
    return true;
  }

  @override
  bool undo() {
    if (!canUndo()) {
      return false;
    }

    final previous = _eventCursor.previousEntry()!;
    final event = _eventCursor.element;
    _eventCursor = previous;
    _snapshot = snapshot.rebuild(event.undoTo);
    return true;
  }

  @override
  bool canRedo() {
    final next = _eventCursor.nextEntry();
    // we are at the head, so we can't redo.
    if (next == null) {
      return false;
    }
    return true;
  }

  @override
  bool redo() {
    if (!canRedo()) {
      return false;
    }
    final next = _eventCursor.nextEntry()!;

    final nextE = next.element;
    _eventCursor = next;
    _snapshot = snapshot.rebuild(nextE.applyTo);
    return true;
  }

  void _removeEventsAfterTheCursor() {
    var next = _eventCursor.nextEntry();
    while (next != null) {
      final toRemove = next;
      next = toRemove.nextEntry();
      toRemove.remove();
    }
  }

  void _addAndMoveCursor(E event) {
    _eventCursor.append(event);
    _eventCursor = _eventCursor.nextEntry()!;
  }

  @override
  S add(E event) {
    _removeEventsAfterTheCursor();
    _addAndMoveCursor(event);
    return _snapshot = snapshot.rebuild(event.applyTo);
  }

  @override
  S addAll(Iterable<E> events) {
    _removeEventsAfterTheCursor();
    final b = snapshot.toBuilder();
    for (final e in events) {
      _addAndMoveCursor(e);
      e.applyTo(b);
    }
    return _snapshot = b.build();
  }

  @override
  S get snapshot => _snapshot;
  S _snapshot;

  @override
  Codec<EventSourcedModel<S, B, E>, Map<String, dynamic>> get codec =>
      DoublyLinkedEventSourcedModelCodec<S, B, E>();

  @override
  ModelUndoState get undoState => ModelUndoState(
        undo: canUndo(),
        redo: canRedo(),
      );
}

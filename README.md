# Allocators

Explicit allocation capabilities and ownership-aware buffer primitives for Swift.

The package is built around one central rule:

> Libraries accept allocation capabilities. Applications choose and own allocation domains.

Allocation policy should remain visible at composition boundaries without forcing every library function to become a memory owner. The API therefore separates the right to allocate from ownership of the resource that makes allocation possible.

## Philosophy

The package aims for explicit low-level control without giving up compile-time ownership safety when Swift can express it.

The main principles are:

1. **Capability is not ownership.** An `Allocator` is permission to allocate and release storage. It does not necessarily own the resource backing that storage.
2. **Allocation domains are explicit.** A bump arena, debug tracker, heap allocator, or future specialized allocator can have different ownership and lifetime semantics while exposing the same allocation capability.
3. **Borrow by default.** Library APIs should normally accept `allocator: borrowing A` rather than consume or retain allocation policy.
4. **Do not erase lifetime information accidentally.** When storage depends on a scoped allocation domain, the safe result should carry that lifetime dependency.
5. **Unsafe control remains available.** Raw pointer/count handles are useful. They are exposed deliberately and named as unsafe rather than pretending they are lifetime-safe.
6. **Avoid unnecessary dynamic dispatch on hot paths.** Generic allocator parameters are preferred over existential allocator boxes unless runtime allocator selection is actually required.
7. **Concurrency is orthogonal.** `Allocator` does not imply `Sendable`; `ConcurrentAllocator` expresses that additional capability explicitly.

## Allocator model

### `Allocator`

The common allocation capability is intentionally able to describe both ordinary escapable allocators and lifetime-bound nonescapable allocator views.

```swift
func parse<A: Allocator & ~Escapable>(
    allocator: borrowing A
) {
    // allocate through A
}
```

A library function should generally neither know nor care whether `A` is backed by the system heap, a debug tracker, or a bump domain.

### `GenericAllocator`

`GenericAllocator` is the normal stateless system allocation capability.

```swift
let allocator = GenericAllocator()

process(
    allocator: allocator
)
```

It is cheap, copyable, and concurrently usable. It carries capability rather than resource ownership.

### `DebugAllocator`

`DebugAllocator` is a noncopyable owner of a tracked allocation domain. Pass its copyable `allocator` handle through normal allocating APIs and retain the owner where inspection is needed.

```swift
let memory = DebugAllocator(
    alloc: GenericAllocator()
)

let allocator = memory.allocator

process(
    allocator: allocator
)

memory.inspector.assert()
```

The distinction is intentional:

```text
memory       owns the debug/tracking domain
allocator    is the capability passed through the program
```

### `BumpAllocator`

`BumpAllocator` is a uniquely owned monotonic allocation domain.

```swift
let arena = BumpAllocator(
    totalBytes: 1024 * 1024
)

process(
    allocator: arena.allocator
)
```

`arena.allocator` is copyable but `~Escapable`. Its lifetime is borrowed from the arena rather than retained through ARC. This allows cheap allocator propagation while preventing the capability itself from escaping the allocation domain.

Individual bump allocations do not reclaim backing bytes. `clear` deinitializes values, while the arena releases its backing region when the owner dies.

## Buffer ownership layers

The package intentionally exposes three levels of buffer control.

### 1. `BorrowedBuffer` — safe scoped allocation

This is the normal safe API when storage is allocated through a supplied allocation domain.

```swift
let arena = BumpAllocator(
    totalBytes: 4096
)

let buffer = makeBuffer(
    count: 64,
    allocator: arena.allocator
) { index in
    index
}

print(buffer[0])
```

`BorrowedBuffer` is both `~Copyable` and `~Escapable`.

Its lifetime is tied to the allocator supplied to `makeBuffer`, and the allocator may itself be tied to a parent owner such as `BumpAllocator`:

```text
BumpAllocator owner
        ↓ borrowed lifetime
BumpAllocator.Handle
        ↓ borrowed lifetime
BorrowedBuffer
```

The buffer stores the allocator capability that created it and automatically clears its storage when the buffer leaves scope. This prevents both accidental lifetime escape and accidental cleanup through a different allocator.

This is the layer to prefer when a caller has a scoped allocation domain and wants the compiler to preserve that relationship.

### 2. `OwnedBuffer` — escapable ownership

Use `OwnedBuffer` when the buffer itself must survive independently of a local borrowed allocation domain.

```swift
let buffer = makeOwnedBuffer(
    count: 64,
    allocator: GenericAllocator()
) { index in
    index
}

return buffer
```

`OwnedBuffer` is noncopyable so there is a single allocation owner, but it is otherwise escapable. It consumes an ordinary escapable allocator capability into itself and uses that capability during destruction.

A lifetime-bound allocator such as `BumpAllocator.Handle` cannot be used to create an `OwnedBuffer`; doing so would allow the allocation to escape the arena that owns its backing storage.

A debug allocator handle can be used because the handle itself owns the references needed to keep its tracking capability valid:

```swift
let memory = DebugAllocator(
    alloc: GenericAllocator()
)

let buffer = makeOwnedBuffer(
    count: 32,
    allocator: memory.allocator
) { _ in 0 }
```

### 3. `BufferHandle` — explicit unsafe control

`BufferHandle` is the raw `{ pointer, count }` representation.

```swift
let handle = makeUnsafeBufferHandle(
    count: 64,
    allocator: allocator
) { index in
    index
}

// manual lifetime responsibility

destroyUnsafeBufferHandle(
    handle,
    allocator: allocator
)
```

It is deliberately escapable and deliberately does not carry allocator lifetime information.

This makes it suitable for low-level interoperability and cases where the caller intentionally knows more than the type system, but it can dangle if the underlying allocation domain dies first.

The unsafe spelling is intentional: crossing into a raw handle is an explicit decision to take lifetime responsibility away from the compiler.

## Choosing a buffer API

Use the narrowest level of control that fits the job:

| Need | API |
| --- | --- |
| Storage scoped to an allocator/domain | `makeBuffer` → `BorrowedBuffer` |
| Storage must escape and own cleanup | `makeOwnedBuffer` → `OwnedBuffer` |
| Raw pointer/count interoperability | `makeUnsafeBufferHandle` → `BufferHandle` |

The safe path gets the simplest name. Unsafe behavior is opt-in and visible at the call site.

## Library authoring

Allocation-aware libraries should normally accept a generic borrowed capability:

```swift
func decode<A: Allocator & ~Escapable>(
    bytes: borrowing Input,
    allocator: borrowing A
) -> Result {
    ...
}
```

That permits callers to choose their allocation strategy without the library owning or type-erasing it.

A larger application can therefore propagate one capability through many layers:

```text
application chooses allocation domain
        ↓
subsystem accepts allocator
        ↓
parser accepts allocator
        ↓
builder accepts allocator
        ↓
container allocates
```

The application owns policy. Libraries consume capability.

## Ownership annotations

Use ownership annotations because they express real semantics, not as decoration.

- `borrowing` means a callee temporarily uses a value or capability without taking ownership.
- `consuming` means ownership intentionally transfers into another owner or ends.
- `~Copyable` represents unique resource ownership where accidental copies would be incorrect.
- `~Escapable` represents values that cannot leave the lifetime context that makes them valid.
- `@_lifetime` is currently used where the experimental Swift lifetime features are required to express dependencies between those values.

The package currently enables `LifetimeDependence` and `Lifetimes` for these APIs.

## Concurrency

Allocation and concurrency are separate concerns.

```swift
protocol Allocator: ~Escapable { ... }
protocol ConcurrentAllocator: Allocator, Sendable {}
```

`GenericAllocator` is concurrently usable. `DebugAllocator.Handle` becomes a `ConcurrentAllocator` when its underlying allocator is concurrent. A bump allocator handle intentionally does not claim concurrent allocation safety.

Do not add `Sendable` merely because something conforms to `Allocator`.

## Debugging and inspection

Inspection is also orthogonal to allocation.

`MemoryInspecting` belongs to owners such as `DebugAllocator`, not to every allocation capability. This prevents ordinary allocator call sites from carrying tracking state or inspection APIs they do not need.

Typical use:

```swift
let memory = DefaultDebugAllocator(
    alloc: GenericAllocator()
)

run(
    allocator: memory.allocator
)

memory.inspector.assert()
```

## Unsafe boundaries

Swift lifetime checking can only protect relationships that remain represented in the type system.

These operations intentionally cross out of that protection:

- constructing or retaining `BufferHandle`;
- using `withUnsafeHandle` and allowing the supplied raw handle to escape;
- directly retaining an `UnsafePointer` or `UnsafeMutablePointer` beyond the lifetime of its allocation domain;
- manually destroying storage through an allocator unrelated to the one that produced it.

Unsafe access is supported because low-level systems code sometimes requires it. It is not the default API.

## Testing ownership

The package has ordinary runtime suites plus a dedicated `talloc_ownership` compiler-contract suite.

Ownership fixtures verify both positive and negative compilation behavior, including properties such as:

- a bump allocator handle can flow through borrowed generic APIs;
- the bump owner itself is noncopyable;
- a nonescapable handle cannot satisfy an ordinary escapable generic requirement;
- a bump handle cannot enter ordinary escaping containers;
- the bump handle is not a `ConcurrentAllocator`;
- a lifetime-bound buffer cannot escape its allocator domain;
- an owned buffer can escape when backed by an escapable allocator;
- unsafe `BufferHandle` values remain intentionally escapable.

Compiler diagnostics are not treated as the contract. The important assertion is whether a fixture compiles or fails to compile.

## Current compiler caveat

The repository also keeps a reproducer for a Swift lifetime-checker gap involving consumption of an owner followed by later use of a dependent handle. That reproducer is documented but is not counted as a passing negative contract until the compiler consistently rejects it across module boundaries.

Do not weaken the ownership model merely to accommodate that checker gap.

## Future direction

Swift's `Span` and `MutableSpan` family is a natural next integration point for safe contiguous views. The package should prefer lifetime-preserving span projections over unrestricted pointer exposure where those APIs fit.

The architecture should continue to preserve the same progressive-disclosure model:

```text
safe lifetime-bound API
        ↓ explicit opt-in
owned/manual API
        ↓ explicit unsafe opt-in
raw pointers and handles
```

Consumers should be able to choose how much control they need, while the easiest path remains the one with the strongest correctness guarantees.

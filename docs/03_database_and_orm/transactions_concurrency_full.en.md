# Transactions, Locking and Concurrency in Django + PostgreSQL

> This document is for backend developers who want to understand
> how data integrity is maintained in concurrent systems.
> Inside: an MVCC deep dive, select_for_update(), race conditions, deadlocks and how to resolve them.

---

> 🔬 **Live transaction examples:**
> [`docs/reference/legacy_source/orm_laboratory_reference.md`](../reference/legacy_source/orm_laboratory_reference.md)
>
> | Concept | Notebook section |
> |-----------|-----------------|
> | `transaction.atomic()` — BEGIN / COMMIT / ROLLBACK | `## 13. 🔒 Транзакції` |
> | `F()` expressions — race-condition safe | `## 6. 📐 F() Expressions` |
> | `select_for_update()` — row locking | `## 13. 🔒 Транзакції` |
> | Duplicate query detection | `## 11. 🔬 SQL Inspection` — `connection.queries` |



> **🧠 Mental model:** A server processes thousands of requests at the same time. Each request can read and modify data. Without proper concurrency control, data gets corrupted: balances are increased incorrectly, items are sold twice, important operations are performed only partially. Transactions, MVCC and locking are the mechanisms that prevent this chaos.
>
> **📚 Why this matters for an ordinary Django project:** Even a simple product page can become a problem with 1000 concurrent shoppers. `note.views_count += 1` in a loop with 1000 parallel requests = a race condition = 999 views lost. Understanding transactions = writing reliable code.
>
> **🌐 Where it lives in Django:** `transaction.atomic()`, `select_for_update()`, `F()`, `on_commit()` are the Python API for managing PostgreSQL transactions and locks.
>
> **❌ Common mistake:** Thinking that `save()` is already "atomic". `Note.objects.create()` + `NoteRevision.objects.create()` are TWO separate INSERTs, two separate transactions. If an exception happens between them → the Note is saved, the Revision is not → corrupted state. You need `transaction.atomic()`.

---

## 1. MVCC in detail

---
> **🧠 Mental model:** MVCC = Multi-Version Concurrency Control. Imagine Google Docs: several people open a document at the same time. Each sees the version as of the moment they opened it. Someone saves changes — the others don't see them yet (or do, depending on refresh). PostgreSQL does the same: every transaction sees a snapshot of the database state.
>
> **📚 Readers don't block writers:** This is a key difference between PostgreSQL and MySQL InnoDB (where readers can also block). In PostgreSQL, `SELECT` never blocks `INSERT/UPDATE/DELETE` and vice versa. They see different row versions (MVCC).
>
> **🌐 Isolation levels:** `READ COMMITTED` — each query in a transaction sees fresh committed data. `REPEATABLE READ` — the snapshot is fixed at the start of the transaction. `SERIALIZABLE` — transactions execute as if sequentially (safest, slowest).
>
> **❌ Common mistake:** Thinking that `READ COMMITTED` gives an "exact" result for two queries within one transaction. `READ COMMITTED` = each query sees newly committed data. If someone committed between your two SELECTs, the second SELECT sees the new data. For a "frozen snapshot" → `REPEATABLE READ`.
---

```python
# Demonstrating MVCC and isolation levels:

from django.db import transaction, connection

# READ COMMITTED (default):
with transaction.atomic():
    count1 = Note.objects.filter(user=user).count()  # → 100
    # Another process: Note.objects.create(user=user, ...)
    count2 = Note.objects.filter(user=user).count()  # → 101 (sees the new note!)
    # READ COMMITTED: every SELECT sees newly committed data

# REPEATABLE READ:
with transaction.atomic():
    connection.cursor().execute('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ')
    count1 = Note.objects.filter(user=user).count()  # → 100
    # Another process: Note.objects.create(user=user, ...)
    count2 = Note.objects.filter(user=user).count()  # → 100 (snapshot frozen!)
    # REPEATABLE READ: the snapshot is fixed at the start of the transaction
```

```
PostgreSQL isolation levels:

Level             | Dirty Read | Non-Repeatable | Phantom Read
──────────────────┼────────────┼────────────────┼─────────────
READ UNCOMMITTED  | Possible¹  | Possible       | Possible
READ COMMITTED    | ✅ Protected| Possible       | Possible
REPEATABLE READ   | ✅ Protected| ✅ Protected    | ✅ Protected²
SERIALIZABLE      | ✅ Protected| ✅ Protected    | ✅ Protected

¹ PostgreSQL always uses READ COMMITTED as the minimum
² PostgreSQL REPEATABLE READ protects against phantoms (a difference from the SQL standard)
```

---

## 2. transaction.atomic() — the full mechanics

---
> **🧠 Mental model:** `with transaction.atomic():` is a "safety bubble". Everything that happens inside is either executed COMPLETELY or canceled COMPLETELY. There is no "half an operation" or "partially saved data". A bank transfer: withdraw from A, add to B — either both operations, or neither.
>
> **📚 SQL lifecycle:** `transaction.atomic()` → SQL `BEGIN` (if not yet in a transaction) or `SAVEPOINT` (if already in a transaction). On success → `COMMIT` or `RELEASE SAVEPOINT`. On an exception → `ROLLBACK` or `ROLLBACK TO SAVEPOINT`.
>
> **🌐 Nested atomic():** Django implements them via **Savepoints**. The outer `atomic()` = `BEGIN`. The inner `atomic()` = `SAVEPOINT sp_1`. If the inner one raises an exception → `ROLLBACK TO SAVEPOINT sp_1` (only the inner one is canceled). The outer one continues.
>
> **❌ CRITICAL mistake:** `try/except` inside `atomic()`. If you catch a DB error (for example, `IntegrityError`) inside a transaction, the transaction is in an "aborted" state, while the code carries on as if all is well. (A plain Python exception such as `ValueError` doesn't break the transaction.) The next `Note.objects.create()` will raise `TransactionManagementError: You can't execute queries until the end of the 'atomic' block.` Catch OUTSIDE atomic or in a nested `atomic()` (savepoint), never just inside!
---

```python
from django.db import transaction
import logging

logger = logging.getLogger(__name__)


# ✅ CORRECT: atomic() → all operations either all succeed or none do
def transfer_note(note_id, from_notebook, to_notebook, user):
    """
    Move a note between notebooks.
    Atomic operation: either both UPDATEs run, or neither.
    """
    with transaction.atomic():
        note = Note.objects.select_for_update().get(id=note_id, user=user)
        note.notebook = to_notebook
        note.save(update_fields=['notebook'])
        
        # Log the move (if this fails → the note is rolled back too)
        NoteActivity.objects.create(
            note=note,
            action='moved',
            from_notebook=from_notebook,
            to_notebook=to_notebook,
        )
    # COMMIT happens only here — after successfully leaving the block


# ❌ WRONG: catch inside atomic()
def wrong_create_note(title, user):
    with transaction.atomic():
        note = Note.objects.create(title=title, user=user)
        try:
            # If a DB query fails here, the transaction is "broken"!
            send_notification(user)  # suppose it writes to the DB and raises IntegrityError
        except Exception:
            pass  # ← DISASTER (for DB errors)!
            # PostgreSQL is now in an aborted state, but the code carries on as if all is well
            # Next query in this atomic(): TransactionManagementError!
            # (a plain Python exception, e.g. ValueError, does NOT break the transaction)
    # On leaving atomic(), Django does a ROLLBACK — the note is silently not saved


# ✅ CORRECT: catch OUTSIDE atomic()
def correct_create_note(title, user):
    try:
        with transaction.atomic():
            note = Note.objects.create(title=title, user=user)
            send_notification(user)  # if it fails → ROLLBACK of the Note
    except Exception as e:
        logger.error(f"create_note failed: {e}")
        return None
    return note  # we get here only if everything is OK


# Nested atomic() — Savepoints:
def create_note_with_optional_revision(title, content, user):
    with transaction.atomic():              # BEGIN
        note = Note.objects.create(
            title=title, content=content, user=user
        )                                    # INSERT note

        try:
            with transaction.atomic():      # SAVEPOINT sp_1
                NoteRevision.objects.create(
                    note=note, content=content, version=1
                )                           # INSERT revision
        except Exception:
            pass
            # ROLLBACK TO SAVEPOINT sp_1 (only the revision was rolled back)
            # The Note remains!

    # COMMIT — the note is saved, the revision maybe not (depending on the exception)
```

---

## 3. Savepoints — nested transactions

---
> **🧠 Mental model:** A savepoint is a "checkpoint" inside a transaction. Like in a game: `SAVEPOINT` = save your progress on a level. If you die → `ROLLBACK TO SAVEPOINT` = return to the checkpoint without starting the game over.
>
> **📚 Django and Savepoints:** Every nested `with transaction.atomic():` automatically becomes a savepoint if we are already in a transaction. You don't write SQL directly — Django decides by itself: `BEGIN` or `SAVEPOINT`.
>
> **🌐 Where this is useful:** Operations with "optional" parts. The main operation is mandatory. The extra one is desirable but not critical. If the extra one raises an exception → only it is rolled back. The main one is saved.
---

```
Sequence Diagram — Savepoints:

Django                  PostgreSQL
  │                         │
  │  with transaction.atomic():
  │ ────BEGIN──────────────► │
  │                          │
  │  Note.objects.create()  │
  │ ────INSERT note─────────► │
  │                          │
  │  with transaction.atomic():  (nested!)
  │ ────SAVEPOINT sp_1──────► │
  │                          │
  │  NoteRevision.create()   │
  │ ────INSERT revision─────► │
  │                          │
  │  (on exception):         │
  │ ────ROLLBACK TO sp_1────► │  (only the revision was rolled back)
  │  (on success):           │
  │ ────RELEASE sp_1────────► │  (savepoint released)
  │                          │
  │ ────COMMIT───────────────► │  (note saved)
```

---

## 4. select_for_update() — row-level locks

---
> **🧠 Mental model:** `select_for_update()` is an "occupied" sign on a resource. When T1 executes `SELECT FOR UPDATE`, PostgreSQL places a lock on the row. T2 tries to execute `SELECT FOR UPDATE` on the same row → it waits until T1 does COMMIT or ROLLBACK.
>
> **📚 Why it's needed:** Without a lock: T1 and T2 both read `stock=1`, both compute `1-1=0`, both write `stock=0`. The item was sold twice. With `SELECT FOR UPDATE`: T1 locked the row, T2 waits. T1 writes `stock=0` and COMMITs → T2 reads `stock=0` → doesn't sell (stock is empty).
>
> **🌐 Options:** `nowait=True` — raises an error instead of waiting. `skip_locked=True` — skips locked rows (for a task queue). `of=('table',)` — lock only a specific table in a JOIN.
>
> **❌ Common mistake:** `select_for_update()` WITHOUT `transaction.atomic()`. The lock is released only on COMMIT or ROLLBACK. Without atomic, Django is in autocommit mode — every query = its own COMMIT → the lock is released right after the SELECT. The point of the lock is lost.
---

```python
from django.db import transaction

# ALWAYS inside transaction.atomic()!

# Basic select_for_update:
def book_ticket(event_id, user):
    """Buying a ticket — a classic race condition scenario."""
    with transaction.atomic():
        # SELECT ... FOR UPDATE → locks the event row
        event = Event.objects.select_for_update().get(id=event_id)
        
        if event.available_tickets <= 0:
            raise ValueError("Tickets are sold out")
        
        # Only ONE process runs this code at a time here (lock!)
        event.available_tickets -= 1
        event.save(update_fields=['available_tickets'])
        
        Ticket.objects.create(event=event, user=user)
    # COMMIT → the lock is released → the next process can read


# nowait=True — raise an error if the row is already locked
def try_process_note(note_id, user):
    """If the note is already being processed — refuse (don't wait)."""
    try:
        with transaction.atomic():
            note = Note.objects.select_for_update(nowait=True).get(
                id=note_id, user=user
            )
            # Fast operation without waiting
            note.status = 'processing'
            note.save(update_fields=['status'])
    except Exception as e:
        if 'could not obtain lock' in str(e):
            return {'error': 'The note is already being processed, try again later'}
        raise


# skip_locked=True — for a task queue (skip busy rows)
def process_pending_tasks():
    """
    A Celery-like pattern for processing a queue.
    skip_locked=True: if a row is locked by another worker → skip it.
    Don't wait (that would slow down the queue).
    """
    with transaction.atomic():
        tasks = Task.objects.select_for_update(
            skip_locked=True
        ).filter(status='pending')[:10]  # take 10 at a time
        
        for task in tasks:
            task.status = 'processing'
            task.save(update_fields=['status'])
        
        return list(tasks)
```

---

## 5. Race Condition — Lost Update

---
> **🧠 Mental model:** A race condition = a "race" between two processes. Both read the same value, both "win" the contest to write first → the second overwrites the first. A "Lost Update".
>
> **📚 Classic example:** A view counter. 1000 parallel requests all read `views=100`, all write `views=101`. Instead of `views=1100` we get `views=101`. 999 views are "lost".
>
> **🌐 The F() solution:** `Note.objects.filter(pk=42).update(views=F('views')+1)` → `UPDATE notes SET views = views + 1 WHERE id=42` → an atomic operation at the PostgreSQL level, a race condition is impossible.
>
> **❌ Common mistake:** `note = Note.objects.get(pk=42); note.views += 1; note.save()` — the classic lost update pattern. Always use `F()` for counters.
---

```
Race Condition — Lost Update (without F()):

Time  | Process A               | Process B
─────────────────────────────────────────────
T=1   | SELECT views=100        |
T=2   |                         | SELECT views=100
T=3   | views = 100 + 1 = 101   |
T=4   |                         | views = 100 + 1 = 101
T=5   | UPDATE views=101        |
T=6   |                         | UPDATE views=101  ← overwrote A!
Result: views=101 instead of 102. With 1000 processes → views=101 instead of 1100!
```

```python
from django.db.models import F

# ❌ RACE CONDITION (with concurrent requests):
def increment_views_UNSAFE(note_id):
    note = Note.objects.get(id=note_id)  # SELECT: reads views=100
    note.views_count += 1                # Python: 100+1=101
    note.save()                          # UPDATE: sets views=101
    # 2 operations, a race condition between them!

# ✅ SAFE — an atomic UPDATE at the PostgreSQL level:
def increment_views_SAFE(note_id):
    Note.objects.filter(id=note_id).update(
        views_count=F('views_count') + 1
    )
    # 1 SQL: UPDATE notes SET views_count = views_count + 1 WHERE id=?
    # PostgreSQL performs read+write atomically — a race condition is impossible

# ✅ SAFE — for more complex logic (select_for_update):
def increment_with_cap(note_id, max_views=10000):
    """Increment, but not beyond max_views."""
    with transaction.atomic():
        note = Note.objects.select_for_update().get(id=note_id)
        if note.views_count < max_views:
            note.views_count += 1
            note.save(update_fields=['views_count'])
```

---

## 6. Race Condition — Double Submit

---
> **🧠 Mental model:** Double submission: the user clicked "Buy" twice (or a double click, or network latency). Two HTTP POST requests fly at the same time. Without protection — two identical orders. An idempotency key is a unique token that lets "repeated" requests avoid creating a duplicate.
>
> **📚 Idempotency Key:** The client generates a UUID and sends it with every request. The server stores the idempotency_key in the database. On a second request with the same key → it returns the same result instead of creating a new one. A UniqueConstraint on idempotency_key guarantees this at the database level.
>
> **🌐 Django implementation:** An `IntegrityError` when trying to INSERT a duplicate idempotency_key → we catch it in the view → return the existing result.
---

```python
import uuid
from django.db import IntegrityError

class Order(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    total_price = models.DecimalField(max_digits=10, decimal_places=2)
    # Idempotency key — a unique token from the client
    idempotency_key = models.UUIDField(unique=True, default=uuid.uuid4)
    # UniqueConstraint guarantees: one key → one order (even under a race condition)


def create_order_idempotent(user, cart, idempotency_key):
    """
    Idempotent order creation.
    Two parallel requests with the same key → only one order.
    """
    try:
        with transaction.atomic():
            order = Order.objects.create(
                user=user,
                total_price=cart.total,
                idempotency_key=idempotency_key,
            )
            # Further logic...
            return order, 'created'
    except IntegrityError:
        # A second request with the same key → UNIQUE violation → return the existing one
        existing = Order.objects.get(idempotency_key=idempotency_key)
        return existing, 'already_exists'
```

---

## 7. Deadlock — mutual blocking

---
> **🧠 Mental model:** A deadlock = two transactions waiting for each other. T1 locked row A and waits for B. T2 locked row B and waits for A. Both wait forever. PostgreSQL detects the deadlock and automatically kills one of them (psycopg raises `DeadlockDetected`, which reaches Django code as `OperationalError`).
>
> **📚 When it happens:** With a different locking order. T1: `lock(note_1) → lock(note_2)`. T2: `lock(note_2) → lock(note_1)`. If T1 locked note_1 and T2 locked note_2 at the same time → deadlock.
>
> **🌐 Prevention:** Always lock in one **stable order** (for example, by id ASC). If T1 and T2 always take the lock on the smaller id first → T1 takes note_1, T2 waits for note_1 → T1 takes note_2 → COMMIT → T2 gets note_1 → takes note_2 → COMMIT. A deadlock is impossible!
>
> **❌ Common mistake:** A different locking order in different views. View A: `lock(user) → lock(note)`. View B: `lock(note) → lock(user)`. With simultaneous requests → deadlock.
---

```python
# ❌ DEADLOCK POTENTIAL:
def transfer_A_to_B(note_a_id, note_b_id, user):
    with transaction.atomic():
        a = Note.objects.select_for_update().get(id=note_a_id)  # lock A
        b = Note.objects.select_for_update().get(id=note_b_id)  # waits for B
        ...

def transfer_B_to_A(note_a_id, note_b_id, user):
    with transaction.atomic():
        b = Note.objects.select_for_update().get(id=note_b_id)  # lock B
        a = Note.objects.select_for_update().get(id=note_a_id)  # waits for A ← DEADLOCK!
        ...


# ✅ SOLUTION: always lock in a stable order (by id ASC):
def transfer_notes_safe(note_a_id, note_b_id, user):
    with transaction.atomic():
        # ALWAYS lock in ascending id order
        notes = Note.objects.select_for_update().filter(
            id__in=[note_a_id, note_b_id]
        ).order_by('id')  # ← STABLE ORDER!

        note_map = {n.id: n for n in notes}
        note_a = note_map[note_a_id]
        note_b = note_map[note_b_id]
        # Logic...


# ✅ RETRY on Deadlock (for complex systems):
import time
import random
from django.db import OperationalError

def with_deadlock_retry(func, max_retries=3, base_delay=0.1):
    """
    Decorator: retries the operation on a deadlock.
    Exponential backoff + jitter (random delay).
    """
    for attempt in range(max_retries):
        try:
            return func()
        except OperationalError as e:
            if 'deadlock detected' in str(e).lower() and attempt < max_retries - 1:
                delay = base_delay * (2 ** attempt) + random.uniform(0, 0.1)
                time.sleep(delay)
                continue
            raise

# Usage:
with_deadlock_retry(lambda: transfer_notes_safe(a_id, b_id, user))
```

---

## 8. on_commit() — actions after a successful commit

---
> **🧠 Mental model:** `on_commit()` means "send the email **only if** the order was saved successfully". If the transaction was rolled back → the email is not sent. If the commit succeeded → the email is sent. Never send a Celery task or an email inside `atomic()` — the transaction is not finished yet and may be rolled back!
>
> **📚 The common mistake without on_commit:** `celery_task.delay(note.id)` inside `transaction.atomic()`. The Celery task starts immediately. The task tries to read the note → it is not in the database yet (the transaction hasn't finished). The task fails or sees the wrong state.
>
> **🌐 How it works:** Django accumulates `on_commit` callbacks. After a successful `COMMIT`, it runs all callbacks in registration order. On `ROLLBACK`, the callbacks are NOT run.
---

```python
from django.db import transaction

def create_note_with_notification(user, title, content):
    with transaction.atomic():
        note = Note.objects.create(
            title=title, content=content, user=user
        )
        
        # ❌ WRONG: the email may be sent even if the transaction was rolled back!
        # send_notification_email.delay(note.id)
        
        # ✅ CORRECT: send only after a successful COMMIT
        transaction.on_commit(
            lambda: send_notification_email.delay(note.id)
        )
        
        # ✅ You can register several callbacks:
        transaction.on_commit(
            lambda: update_search_index.delay(note.id)
        )
        transaction.on_commit(
            lambda: send_webhook.delay('note_created', note.id)
        )
    
    # After this line: the COMMIT has been executed
    # on_commit callbacks run in registration order
    # If a problem occurs between on_commit(email) and on_commit(webhook) —
    # the email has already been sent (each callback runs independently)
    
    return note
```

---

## 9. Isolation Levels and a solution for each scenario

```python
# Setting the isolation level for a specific transaction:

from django.db import transaction, connection

def critical_report_generation(user_id):
    """
    A financial report: needs a consistent snapshot.
    REPEATABLE READ: all SELECTs in the transaction see one snapshot.
    """
    with transaction.atomic():
        connection.cursor().execute(
            'SET TRANSACTION ISOLATION LEVEL REPEATABLE READ'
        )
        
        total_notes = Note.objects.filter(user_id=user_id).count()
        published = Note.objects.filter(user_id=user_id, status='published').count()
        
        # If someone adds a note between these two COUNTs — we won't see it
        # (REPEATABLE READ: the snapshot is frozen)
        
        return {'total': total_notes, 'published': published}


def book_last_seat(event_id, user_id):
    """
    Booking the last seat: SERIALIZABLE for maximum safety.
    """
    with transaction.atomic():
        connection.cursor().execute(
            'SET TRANSACTION ISOLATION LEVEL SERIALIZABLE'
        )
        
        event = Event.objects.get(id=event_id)
        
        if event.seats_available <= 0:
            raise ValueError("No seats available")
        
        # SERIALIZABLE guarantees: if T1 and T2 both see seats=1,
        # one of them will get a SerializationFailure and will be retried
        event.seats_available -= 1
        event.save()
        
        Booking.objects.create(event=event, user_id=user_id)
```

---

## 10. A practical decision table

| Problem | Solution | Django API |
|----------|---------|------------|
| Counter (N+1 race) | Atomic UPDATE | `F('count') + 1` |
| Partial operation | Atomic transaction | `transaction.atomic()` |
| Concurrent read-write | Row-level locking | `select_for_update()` |
| Double submit | Idempotency key | `UNIQUE` + catch `IntegrityError` |
| Deadlock | Stable lock order | `order_by('id')` before locking |
| Email after save | After commit | `on_commit(lambda: task.delay(...))` |
| Consistent snapshot | REPEATABLE READ | `SET TRANSACTION ISOLATION LEVEL` |

---

## Prediction Exercises

### Exercise 1: F() vs save()

```python
# Option A:
note = Note.objects.get(pk=42)
note.likes += 1
note.save()

# Option B:
Note.objects.filter(pk=42).update(likes=F('likes') + 1)
```

**Question:** With 1000 simultaneous requests for each option — what is the result?

> **Option A:** All 1000 read `likes=0`, all write `likes=1`. Result: `likes=1` (999 updates lost!)
>
> **Option B:** Each UPDATE atomically increments by 1. Result: `likes=1000` (no update lost!)

### Exercise 2: atomic() Exception

```python
with transaction.atomic():
    note = Note.objects.create(title='Test')
    try:
        raise ValueError("oops")
    except ValueError:
        pass
    note2 = Note.objects.create(title='Test2')  # what happens here?
```

**Question:** How many notes will be created?

> **Answer:** **Both** notes are saved. `ValueError` is a plain Python exception unrelated to the DB: PostgreSQL knows nothing about it, and the transaction stays usable. A `TransactionManagementError` would appear only if a **DB operation** failed inside the `try` (for example, `IntegrityError`) and was caught without a nested `atomic()`: then the transaction enters the aborted state, the next `create()` raises `TransactionManagementError`, and on leaving the block a ROLLBACK happens (no note is saved). The rule: catch DB errors OUTSIDE `atomic()`, or wrap the risky operation in a nested `atomic()` (savepoint).

---

## Self-check questions

1. Why shouldn't you use `try/except` inside `transaction.atomic()`?
2. What is a Savepoint and when does Django use it?
3. What is the difference between `select_for_update(nowait=True)` and `select_for_update(skip_locked=True)`?
4. What is a Lost Update and how does F() prevent it?
5. What is a Deadlock and how do you avoid it?
6. Why do we need `on_commit()` and why shouldn't you send an email/task inside atomic()?
7. What is the difference between READ COMMITTED and REPEATABLE READ?
8. What is an idempotency key and in which scenarios is it needed?
9. Why must `select_for_update()` ALWAYS be inside `transaction.atomic()`?
10. PostgreSQL detected a deadlock and killed one transaction. Which one? What will the killed transaction receive?

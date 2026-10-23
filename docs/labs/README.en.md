# Labs — Practical exercises

Lab exercises without ready-made solutions. The tasks are tied to the real Notes Chat App code: each exercise is verified by running tests or the Django shell.

| Lab | Topic | Key files |
|-----|------|--------------|
| [ORM Lab](orm_lab.md) | N+1, `select_related`, `prefetch_related`, `annotate` | `selectors.py` |
| [Forms Lab](forms_lab.md) | Scoped queryset, custom `clean_<field>()`, IDOR through a form | `forms.py`, `test_forms.py` |
| [Testing Lab](testing_lab.md) | Regression test, IDOR, permission bug, `TransactionTestCase` | `test_views.py`, `test_consumers.py` |
| [Async Lab](async_lab.md) | WebSocket lifecycle, `database_sync_to_async`, `WebsocketCommunicator` | `consumers.py`, `test_consumers.py` |

# Final Project Testing Strategy

| Test file | Purpose |
| --- | --- |
| `test_models.py` | model rules |
| `test_services.py` | business operations |
| `test_forms.py` | validation and scoped querysets |
| `test_views.py` | HTTP access and redirects |
| `test_consumers.py` | WebSocket consumer |
| `test_selenium.py` | browser flows |

Run:

```bash
python manage.py test notes_app.tests.test_models -v 2
python manage.py test notes_app.tests.test_services -v 2
python manage.py test notes_app.tests.test_views -v 2
```

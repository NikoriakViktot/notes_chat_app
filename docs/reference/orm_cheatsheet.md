# ORM Cheatsheet

```python
Note.objects.filter(user=user)
Note.objects.select_related('notebook')
Note.objects.prefetch_related('tags')
Notebook.objects.annotate(note_count=Count('notes'))
```

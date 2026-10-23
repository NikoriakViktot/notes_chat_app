# Common Security Mistakes — Security Misconceptions

> **Goal:** Dispel common misconceptions about web application security.
> EVEN experienced developers make these mistakes!

---

## Mistake 1: "I hid the button, so it's protected"

**What people do:** Hide the "Delete" button in the template for users without permission.

```html
<!-- template: we hide the button — BUT this is only UX, NOT security! -->
{% if note.user == request.user %}
  <a href="/notes/{{ note.pk }}/delete/">Delete</a>
{% endif %}
```

**The problem:** An attacker opens the developer tools (F12), sees the note ID and sends the request directly:

```bash
# The attacker knows the URL: /notes/42/delete/
# They send a POST request directly via curl or Postman:
curl -X POST http://mysite.com/notes/42/delete/ \
     -H "Cookie: sessionid=attacker_session"
# Result: Bob's note is deleted!
```

**The right solution — protection in the VIEW:**
```python
# views.py:
@login_required
def note_delete(request, pk):
    # The check is ALWAYS in the view, not only in the template:
    note = get_object_or_404(Note, pk=pk, user=request.user)
    # ↑ If note.user != request.user → Django returns 404
    if request.method == 'POST':
        note.delete()
        return redirect('note_list')
```

---

## Mistake 2: "If the user is logged in, they can do anything"

**What people think:** `@login_required` protects against everything.

**The problem:** `@login_required` checks only **the fact of login**, but does NOT check **ownership** of a specific object.

```python
# DANGEROUS — IDOR (Insecure Direct Object Reference):
@login_required
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk)   # pk=42 belongs to Bob
    # Alice is logged in → @login_required OK
    # But Alice is editing BOB's note!

# SAFE — add a user= filter:
@login_required
def note_edit(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)
    # pk=42 belongs to Bob, user=Alice → 404 ✓
```

**Rule:**
> `@login_required` + `get_object_or_404(Model, pk=pk, user=request.user)` = proper protection

---

## Mistake 3: "A superuser is a normal admin"

**What people do:** Test all the functionality as a superuser.

**The problem:**
```python
# Superuser:
user.has_perm('notes_app.delete_note')  # True — ALWAYS, even without an explicit permission

# A regular staff user:
user.has_perm('notes_app.delete_note')  # False — if the permission isn't assigned

# If you test as a superuser and see that everything is OK →
# that DOESN'T mean a regular user will have access too!
```

**Rule:**
> Test each role with **the right account type**: regular user, staff, superuser — separately.

---

## Mistake 4: "A global queryset is fine"

**What people do:** `Note.objects.get(id=note_id)` without filtering by user.

```python
# DANGEROUS — Alice can get any note:
note = Note.objects.get(id=note_id)

# The attacker iterates over IDs: /notes/1/, /notes/2/, /notes/3/...
# → finds other users' confidential notes!

# SAFE:
note = get_object_or_404(Note, id=note_id, user=request.user)
# or
note = Note.objects.get(id=note_id, user=request.user)
```

---

## Mistake 5: "Client-side validation protects us"

**What people do:** Check data only in the HTML form or in JavaScript.

```html
<!-- HTML form: -->
<input type="number" name="priority" min="1" max="4">
<!-- The attacker opens F12 → changes min/max → sends priority=999 -->
```

**Rule:**
> Client-side validation is only for UX (convenience).
> **Server-side validation** is mandatory for security.

```python
# Django ModelForm — server-side validation:
class NoteForm(forms.ModelForm):
    class Meta:
        model = Note
        fields = ['title', 'content', 'priority']
    
    def clean_priority(self):
        priority = self.cleaned_data['priority']
        if priority not in [1, 2, 3, 4]:
            raise forms.ValidationError("Invalid priority")
        return priority
```

---

## Mistake 6: "DEBUG=True in production — just temporarily"

**What people do:** Leave `DEBUG=True` on the server "until they find the bug".

**What an attacker gets from DEBUG=True:**
```
- The full error stack trace (file names, lines of code)
- The values of all local variables at the moment of the error
- The values of `settings` (Django masks `SECRET_KEY` and passwords as `********`, but secrets with "innocent" names are shown)
- All SQL queries are kept in memory → memory leak!
```

**Rule:**
> `DEBUG = False` **always** in production. No exceptions.
> For debugging in production, use logs (`logging`).

---

## Summary: View security checklist

Before every new view, check:

```python
@login_required                                    # ✓ logged in?
def my_view(request, pk):
    obj = get_object_or_404(Model, pk=pk,          # ✓ is there permission for this object?
                             user=request.user)
    
    if request.method == 'POST':
        form = MyForm(request.POST)                # ✓ a form with POST data
        if form.is_valid():                        # ✓ server-side validation
            # ... logic
    
    # Template: hide buttons for UX, but the protection is in the view ✓
    return render(request, 'template.html', {'obj': obj})
```

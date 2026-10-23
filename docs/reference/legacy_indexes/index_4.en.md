# Lesson: Django Authentication and Security — Navigation

> **Project:** `crispy_notes_chat_app` — a notes application with a full auth stack and group access
>
> **Level:** For students who are already familiar with Django basics (models, views, templates, forms)
>
> **What we study:**
> - Authentication and authorization in Django
> - Sessions, cookies, the login/logout flow
> - Password reset and password change
> - Object protection (IDOR prevention)
> - Groups for shared access to notes
> - Django security settings
> - OWASP Top 10 and security architecture

---

## Recommended study order

### Step 1 — Theory: What is security?
📄 **[SECURITY_FOUNDATIONS.md](../../07_auth_and_security/security_foundations_full.md)**

CIA Triad, Trust Boundary, Attack Surface, Defense-in-Depth, password hashing, CSRF, Least Privilege.
Start here if you have never heard of cybersecurity.

---

### Step 2 — Authentication in Django
📄 **[AUTH_BASICS.md](../../07_auth_and_security/auth_basics_full.md)**

- Authentication (who are you?) vs Authorization (what are you allowed to do?)
- Django components: `User`, `authenticate()`, `login()`, `logout()`
- Middleware — how Django "knows" who is sending the request
- `@login_required` — protecting views
- Mermaid diagram: middleware lifecycle

---

### Step 3 — Sessions and the Login/Logout flow
📄 **[SESSIONS_FLOW.md](../../07_auth_and_security/sessions_flow_full.md)**

- Why HTTP "doesn't remember" the user (stateless)
- How cookies and sessions solve this problem
- The full flow: Login → Cookie → Logout
- Mermaid sequence diagram
- Password Reset step by step
- URL routing of auth views

---

### Step 4 — Permissions and Groups
📄 **[PERMISSIONS.md](../../07_auth_and_security/permissions_full.md)**

- What Permissions are in Django (4 basic permissions)
- Object-Level Permissions — protecting specific objects
- IDOR — Insecure Direct Object Reference (attack and defense)
- Groups for shared access ("Family", "Work")
- ER diagram: User, Group, Note

---

### Step 5 — Common mistakes
📄 **[SECURITY_MISCONCEPTIONS.md](../../07_auth_and_security/security_misconceptions_full.md)**

6 common misconceptions:
1. "Hid the button = protected it"
2. "If logged in — can do anything"
3. "Testing as a superuser = everything is OK"
4. "A global queryset is fine"
5. "Client-side validation protects"
6. "DEBUG=True in production — temporarily"

---

### Step 6 — Django Admin
📄 **[DJANGO_ADMIN.md](../../05_frontend_and_templates/django_admin_full.md)**

- What `/admin/` is and who has access to it
- `is_staff` vs `is_superuser` — the difference
- `ModelAdmin` — configuring lists and filters
- How to assign permissions through the Admin
- `python manage.py createsuperuser`

---

### Step 7 — Django security settings
📄 **[DJANGO_SECURITY_ARCHITECTURE.md](../../07_auth_and_security/django_security_architecture_full.md)**

- The full request processing cycle (middleware pipeline)
- Password hashing (PBKDF2)
- ORM — protection against SQL Injection
- CSRF and XSS protection
- File upload security
- Production settings checklist

---

### Step 8 — OWASP Top 10
📄 **[OWASP_TOP_10.md](../../07_auth_and_security/owasp_top_10_full.md)**

The 10 most common web application vulnerabilities and how Django protects against each of them:
A01 Broken Access Control → A10 SSRF

---

### Step 9 — Zero Trust Architecture
📄 **[ZERO_TRUST.md](../../07_auth_and_security/zero_trust_full.md)**

- "Never trust, always verify"
- 6 principles: Continuous Verification, Least Privilege, IAM/MFA, Micro-segmentation, Monitoring
- A Django implementation of each principle with code

---

### Step 10 — SIEM and Logging
📄 **[SIEM.md](../../07_auth_and_security/siem_full.md)**

- What SIEM (Security Information and Event Management) is
- Django LOGGING configuration
- Which events to log (brute-force, IDOR, audit trail)
- Rsyslog + Stunnel for log shipping
- ELK Stack (Elasticsearch, Logstash, Kibana)

---

## Project structure

```
crispy_notes_chat_app/
├── notes_chat_app/
│   ├── settings.py       ← security settings block + EMAIL_BACKEND
│   └── urls.py           ← include('django.contrib.auth.urls')
├── notes_app/
│   ├── models.py         ← Note.group FK, ShoppingList.group FK
│   ├── views.py          ← group views + PermissionDenied
│   ├── selectors.py      ← Q(user=user) | Q(group__in=user_groups)
│   ├── services.py       ← create_group, add_user_to_group
│   ├── forms.py          ← GroupCreateForm, GroupAddMemberForm
│   └── urls.py           ← /groups/ URL patterns
└── templates/
    ├── registration/
    │   ├── login.html                   ← + "Забули пароль?"
    │   ├── password_reset_form.html     ← email form
    │   ├── password_reset_done.html     ← "check your email"
    │   ├── password_reset_confirm.html  ← new password form
    │   ├── password_reset_complete.html ← success
    │   ├── password_reset_email.html    ← email text
    │   ├── password_change_form.html    ← password change
    │   └── password_change_done.html   ← success
    └── notes_app/
        ├── group_list.html
        ├── group_form.html
        ├── group_detail.html
        └── group_confirm_delete.html
```

---

## Quickstart

```bash
cd crispy_notes_chat_app/

# First run:
python manage.py migrate
python manage.py createsuperuser  # for /admin/
python manage.py runserver

# Check the auth URLs:
# http://127.0.0.1:8000/accounts/login/
# http://127.0.0.1:8000/accounts/password_reset/
# http://127.0.0.1:8000/accounts/password_change/

# Check the groups:
# http://127.0.0.1:8000/groups/
# http://127.0.0.1:8000/groups/new/

# Check the Django config:
python manage.py check
```

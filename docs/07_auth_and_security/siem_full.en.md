# SIEM — Security Information and Event Management Systems

> **SIEM** (Security Information and Event Management) is a tool that collects logs from across your server, analyzes them in real time and alerts the administrator about suspicious activity.
>
> **Analogy:** Imagine your house has 100 video cameras. A SIEM is the security guard who watches all the screens at once and presses the alarm button when they notice something suspicious.

---

## What is a SIEM and why do you need it?

**Security Information and Event Management (SIEM) systems** are designed for:
- **Collecting** logs from various sources (Django, nginx, PostgreSQL, system logs)
- **Storing** and indexing large volumes of data
- **Analysis and correlation** — searching for suspicious patterns
- **Threat detection** in real time

**Popular SIEM platforms:**
- **Splunk** — the most popular commercial SIEM
- **ELK Stack (Elasticsearch + Logstash + Kibana)** — free and open-source
- **IBM QRadar** — enterprise level
- **LogRhythm** — for SOC teams (Security Operations Center)

---

## Why isn't simply storing logs locally enough?

```
Problem 1: An attacker breached the server → deleted the log files → no evidence
Problem 2: A 10 GB log file → impossible to read by hand
Problem 3: A Docker container restarted → all the logs are gone
Problem 4: You need to compare Django + nginx + PostgreSQL logs → different files

Solution: A SIEM collects everything in one place and analyzes it automatically
```

---

## Log shipping architecture: Django → SIEM

```
[Django App]
    ↓ (Python logging → SysLogHandler)
[Syslog Daemon (rsyslog)] ← /dev/log socket
    ↓ (stunnel: SSL/TLS encryption)
[SIEM Server (Splunk/ELK)]
    ↓
[Dashboards + Alerts]
```

---

## Step 1: Configuring Django logging (`settings.py`)

Instead of writing to a local file, we send logs to the system `syslog`:

```python
# settings.py

import logging

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    
    'formatters': {
        'security': {
            # Format: [level] [time] [module] message
            'format': '[%(levelname)s] %(asctime)s %(name)s: %(message)s',
        },
    },
    
    'handlers': {
        # Send to the system syslog (/dev/log)
        'syslog': {
            'class': 'logging.handlers.SysLogHandler',
            'address': '/dev/log',           # Linux syslog socket
            'facility': 'local7',            # category for SIEM filtering
            'formatter': 'security',
        },
        # Additionally — to the console during development
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'security',
        },
    },
    
    'loggers': {
        # Django's built-in security logger
        'django.security': {
            'handlers': ['syslog', 'console'],
            'level': 'WARNING',
            'propagate': False,
        },
        # Our custom security logger
        'security': {
            'handlers': ['syslog', 'console'],
            'level': 'INFO',
            'propagate': False,
        },
    },
}
```

---

## Step 2: Which events should you log?

### 2.1. Failed login attempts (Brute-Force Detection)

```python
# views.py
import logging
security_log = logging.getLogger('security')

def login_view(request):
    if request.method == 'POST':
        form = AuthenticationForm(request, data=request.POST)
        if form.is_valid():
            user = form.get_user()
            login(request, user)
            security_log.info(
                f"LOGIN_SUCCESS user_id={user.pk} username={user.username} "
                f"ip={request.META.get('REMOTE_ADDR')}"
            )
        else:
            security_log.warning(
                f"LOGIN_FAILED username={request.POST.get('username', 'unknown')} "
                f"ip={request.META.get('REMOTE_ADDR')}"
            )
```

**A SIEM rule:** If `LOGIN_FAILED` occurs > 5 times within 1 minute from one IP → alert!

### 2.2. Unauthorized access attempts (IDOR Detection)

```python
from django.core.exceptions import PermissionDenied

@login_required
def note_edit(request, pk):
    try:
        note = Note.objects.get(pk=pk)
    except Note.DoesNotExist:
        raise Http404
    
    # Record the attempt to access someone else's resource
    if note.user != request.user:
        security_log.warning(
            f"UNAUTHORIZED_ACCESS user_id={request.user.pk} "
            f"tried to access note_id={pk} owned_by={note.user_id} "
            f"ip={request.META.get('REMOTE_ADDR')}"
        )
        raise PermissionDenied

    # ... rest of the view
```

### 2.3. Privileged actions (Audit Trail)

```python
# We log deletions, permission changes, group operations
@login_required
def note_delete(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)
    if request.method == 'POST':
        security_log.info(
            f"NOTE_DELETED user_id={request.user.pk} note_id={pk} "
            f"note_title={note.title[:50]!r}"
        )
        note.delete()
```

---

## Step 3: Configuring the Syslog Daemon

`rsyslog` is a system daemon that collects logs from applications.

```bash
# /etc/rsyslog.conf or /etc/rsyslog.d/django.conf

# Receive logs from Django (via /dev/log)
local7.*    /var/log/django-security.log

# Forward to the SIEM server (`@` = UDP, port 514, unencrypted)
local7.*    @log.mycompany.com:514

# Variant for stunnel from step 4: `@@` = TCP, to the local tunnel entry
# local7.*    @@127.0.0.1:514
```

```bash
# Restart rsyslog after changes:
sudo systemctl restart rsyslog
```

---

## Step 4: Encrypting log transport (stunnel)

Without encryption, logs travel across the network in plain text! An attacker inside the network can intercept them.

**stunnel** creates an SSL/TLS tunnel for any TCP connection:

```bash
# Installation:
sudo apt install stunnel4

# /etc/stunnel/siem.conf:
[siem-forward]
client = yes
accept = 127.0.0.1:514    # local TCP port (rsyslog writes here via @@)
connect = siem.company.com:6514  # SIEM server (TLS port)
cert = /etc/ssl/certs/client.pem
```

```
Without stunnel:  Django → rsyslog → [open network] → SIEM  ← DANGEROUS
With stunnel:     Django → rsyslog → stunnel (SSL) → [encrypted] → SIEM
```

---

## Step 5: Rules and Alerts in the SIEM

Once the logs arrive in the SIEM, we configure automatic rules:

| Rule | Condition | Action |
|---------|-------|-----|
| Brute-Force | LOGIN_FAILED > 5 within 60 sec from one IP | Email to the administrator |
| IDOR Attack | UNAUTHORIZED_ACCESS > 3 within 5 min | Block the IP (via SOAR) |
| Privilege Escalation | GROUP_ADDED for a new admin | Immediate alert |
| After-Hours Access | Login between 2:00-6:00 | Suspicious activity |
| Mass Deletion | NOTE_DELETED > 10 within 1 min | Possible data leak |

**SOAR** (Security Orchestration, Automation, and Response) — automated incident response:
```
The SIEM detected brute force
    ↓
SOAR automatically:
    1. Blocks the IP at the nginx level
    2. Sends an SMS to the administrator
    3. Opens a ticket in Jira
    4. Saves the IP to a blacklist
```

---

## ELK Stack — a free alternative for learning

**ELK** = **E**lasticsearch + **L**ogstash + **K**ibana

```
Django → rsyslog → Logstash (parsing) → Elasticsearch (storage) → Kibana (dashboards)
```

Kibana lets you build dashboards:
- A chart of login attempts over time
- A map of attackers' IP addresses
- The top 10 most frequent authorization errors

---

## Where is this in our project?

In `crispy_notes_chat_app` a SIEM isn't connected yet. For a learning project this is enough:

```python
# settings.py — minimal security logging:
LOGGING = {
    'version': 1,
    'handlers': {
        'console': {'class': 'logging.StreamHandler'},
    },
    'loggers': {
        'django.security': {
            'handlers': ['console'],
            'level': 'WARNING',
        },
    },
}
```

For production, connect ELK or Splunk following the scheme above.

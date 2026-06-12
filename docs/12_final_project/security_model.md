# Security Model

## Authentication

Django built-in auth handles login, logout, password change/reset. `register` is custom in `notes_app/views.py`.

## Authorization

Object access is scoped by owner, direct sharing, or group membership.

## IDOR protection

Do not fetch mutable objects by `pk` only. Use scoped querysets:

- owner-only for edit/delete;
- owner or group for reading group notes;
- owner or `shared_with` for direct sharing.

## WebSocket security

`GroupChatConsumer.connect()` closes the socket if user is anonymous or not a member of the group.

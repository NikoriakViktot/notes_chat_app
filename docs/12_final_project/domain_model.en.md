# Domain Model

Source: `notes_app/models.py`.

---

## ER diagram

```mermaid
erDiagram
    AUTH_USER ||--|| USER_PROFILE : "1:1 (CASCADE)"
    AUTH_USER ||--o{ NOTEBOOK : "1:N (CASCADE)"
    AUTH_USER ||--o{ NOTE : "1:N (CASCADE)"
    AUTH_USER ||--o{ TAG : "1:N (CASCADE)"
    AUTH_USER ||--o{ TODO_LIST : "1:N (CASCADE)"
    AUTH_USER ||--o{ SHOPPING_LIST : "1:N (CASCADE)"
    AUTH_USER ||--o{ CHAT_MESSAGE : "1:N (CASCADE)"

    AUTH_GROUP ||--o{ NOTE : "FK SET_NULL"
    AUTH_GROUP ||--o{ SHOPPING_LIST : "FK SET_NULL"
    AUTH_GROUP ||--o{ CHAT_MESSAGE : "1:N (CASCADE)"

    AUTH_USER }o--o{ TODO_LIST : "shared_with M2M"
    AUTH_USER }o--o{ SHOPPING_LIST : "shared_with M2M"

    NOTEBOOK ||--o{ NOTE : "FK SET_NULL"
    NOTE }o--o{ TAG : "M2M"
    NOTE ||--o{ REMINDER : "1:N (CASCADE)"
    TODO_LIST ||--o{ TODO_ITEM : "1:N (CASCADE)"
    SHOPPING_LIST ||--o{ SHOP_ITEM : "1:N (CASCADE)"
```

---

## Models and key fields

### UserProfile

| Field | Type | Specifics |
|------|-----|-------------|
| `user` | `OneToOneField(User, CASCADE)` | the linked profile |
| `display_name` | `CharField(100, blank)` | |
| `avatar_url` | `URLField(blank)` | |
| `timezone` | `CharField(50)` | default `'UTC'` |
| `bio` | `TextField(blank)` | |

### Tag

| Field | Type | Specifics |
|------|-----|-------------|
| `user` | `ForeignKey(User, CASCADE)` | |
| `name` | `CharField(50)` | |
| `color` | `CharField(7)` | hex, default `'#808080'` |

`unique_together = [('user', 'name')]`

### Notebook

| Field | Type | Specifics |
|------|-----|-------------|
| `user` | `ForeignKey(User, CASCADE)` | |
| `title` | `CharField(100)` | |
| `description` | `TextField(blank)` | |
| `color` | `CharField(7)` | hex, default `'#4A90E2'` |
| `is_default` | `BooleanField` | default `False` |
| `created_at` | `DateTimeField(auto_now_add)` | |

### Note

| Field | Type | Specifics |
|------|-----|-------------|
| `user` | `ForeignKey(User, CASCADE)` | |
| `group` | `ForeignKey(Group, SET_NULL, null, blank)` | group sharing |
| `notebook` | `ForeignKey(Notebook, SET_NULL, null, blank)` | may have no notebook |
| `tags` | `ManyToManyField(Tag, blank)` | |
| `title` | `CharField(200)` | |
| `content` | `TextField(blank)` | |
| `priority` | `PositiveSmallIntegerField` | 1–4; CheckConstraint |
| `is_pinned` | `BooleanField` | default `False` |
| `is_archived` | `BooleanField` | default `False` |
| `created_at` | `DateTimeField(auto_now_add)` | |
| `updated_at` | `DateTimeField(auto_now)` | |

Priorities: `PRIORITY_LOW=1`, `PRIORITY_MEDIUM=2`, `PRIORITY_HIGH=3`, `PRIORITY_URGENT=4`.

Indexes: `(user, -updated_at)`, `(user, is_pinned)`.

### Reminder

| Field | Type | Specifics |
|------|-----|-------------|
| `note` | `ForeignKey(Note, CASCADE)` | deleting a Note → deletes its Reminders |
| `remind_at` | `DateTimeField` | |
| `message` | `CharField(500, blank)` | |
| `is_sent` | `BooleanField` | default `False` |
| `repeat_pattern` | `CharField(20)` | `none/daily/weekly/monthly` |

### TodoList

| Field | Type | Specifics |
|------|-----|-------------|
| `user` | `ForeignKey(User, CASCADE)` | |
| `title` | `CharField(200)` | |
| `description` | `TextField(blank)` | |
| `is_completed` | `BooleanField` | default `False` |
| `created_at` | `DateTimeField(auto_now_add)` | |
| `shared_with` | `ManyToManyField(User, blank)` | direct sharing with users |

### TodoItem

| Field | Type | Specifics |
|------|-----|-------------|
| `todo_list` | `ForeignKey(TodoList, CASCADE)` | |
| `text` | `CharField(500)` | |
| `is_done` | `BooleanField` | default `False` |
| `order_position` | `PositiveIntegerField` | default `0` |
| `due_date` | `DateField(null, blank)` | |

`ordering = ['order_position', 'id']`

### ShoppingList

| Field | Type | Specifics |
|------|-----|-------------|
| `user` | `ForeignKey(User, CASCADE)` | |
| `group` | `ForeignKey(Group, SET_NULL, null, blank)` | group sharing |
| `title` | `CharField(200)` | |
| `store_name` | `CharField(100, blank)` | |
| `created_at` | `DateTimeField(auto_now_add)` | |
| `shared_with` | `ManyToManyField(User, blank)` | direct sharing with users |

### ShopItem

| Field | Type | Specifics |
|------|-----|-------------|
| `shopping_list` | `ForeignKey(ShoppingList, CASCADE)` | |
| `name` | `CharField(200)` | |
| `quantity` | `DecimalField(8, 2)` | default 1; MinValueValidator(0); CheckConstraint >0 |
| `unit` | `CharField(5)` | choices: шт/кг/л/г (pcs/kg/l/g); default шт |
| `is_purchased` | `BooleanField` | default `False` |
| `estimated_price` | `DecimalField(10, 2, null, blank)` | |

### ChatMessage

| Field | Type | Specifics |
|------|-----|-------------|
| `group` | `ForeignKey(Group, CASCADE)` | deleting a group → all its messages are deleted |
| `author` | `ForeignKey(User, CASCADE)` | deleting a user → all their messages are deleted |
| `content` | `TextField` | |
| `timestamp` | `DateTimeField(auto_now_add)` | |

Index: `(group, timestamp)` — `chat_group_ts_idx`.

---

## Deletion behavior

| Object | What is deleted along with it |
|--------|---------------------|
| `User` deleted | all Notebook, Note, Tag, TodoList, ShoppingList, ChatMessage (CASCADE) |
| `Group` deleted | all ChatMessage (CASCADE); Note.group and ShoppingList.group → NULL (SET_NULL) |
| `Notebook` deleted | Note.notebook → NULL (SET_NULL); the notes remain |
| `Note` deleted | all Reminder (CASCADE) |
| `TodoList` deleted | all TodoItem (CASCADE) |
| `ShoppingList` deleted | all ShopItem (CASCADE) |

---

## Access through sharing

| Object | Sharing mechanism |
|--------|-----------------|
| `Note` | through the `group` FK (Group members can see it) |
| `ShoppingList` | through the `group` FK **and** through the `shared_with` M2M (directly with users) |
| `TodoList` | through the `shared_with` M2M (directly with users) |
| `ChatMessage` | through the group (`Group` membership) |

# Services and Selectors

> A selector reads data, a service changes data, a view coordinates HTTP.

## What the student will learn

- the basic mental model of the topic;
- how the topic works in Django;
- where to see it in the final project;
- how to check that the understanding is not merely theoretical.

## Prerequisites

- Be able to open the repository.
- Understand that all paths in the documentation are relative to the `notes_chat_app` root.

## The rule

| Layer | Does | Does not |
| --- | --- | --- |
| View | request, permissions, forms, render/redirect | complex ORM |
| Selector | SELECT queries | mutations |
| Service | create/update/delete, transaction | HTML response |

This makes the code testable: a service can be tested without HTTP, and a selector can be optimized without changing the template.

## Where to find it in the final project

| File | What to look at |
| --- | --- |
| `notes_app/selectors.py` | read layer |
| `notes_app/services.py` | write layer |
| `notes_app/tests/test_services.py` | service tests |

## Practical task

Move one repeated query into a selector and add a test.

## Review questions

- What is the input to this process?
- What result is expected?
- Where does an error most often occur?
- Which command or test helps verify the change?

## Next

Next: [Auth and security](../07_auth_and_security/README.md).

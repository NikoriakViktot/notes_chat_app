# Templates, Bootstrap and Static Files

> Template inheritance removes HTML duplication and creates a single UI structure.

## What the student will learn

- the basic mental model of the topic;
- how the topic works in Django;
- where to see it in the final project;
- how to check that the understanding is not merely theoretical.

## Prerequisites

- Be able to open the repository.
- Understand that all paths in the documentation are relative to the `notes_chat_app` root.

## Current hierarchy

```text
templates/base.html
└── templates/layouts/dashboard.html
    └── notes_app/templates/notes_app/*.html
```

`base.html` includes Bootstrap and the app CSS. `dashboard.html` adds the sidebar, topbar, messages and the content block.

Static files:

- `notes_app/static/notes_app/css/app.css`;
- `notes_app/static/notes_app/js/group_chat.js`;
- `static/css/project.css`.

## Where to find it in the final project

| File | What to look at |
| --- | --- |
| `templates/base.html` | HTML skeleton |
| `templates/layouts/dashboard.html` | sidebar and topbar |
| `notes_app/context_processors.py` | global sidebar context |

## Practical task

Find out how `sidebar_notebooks` gets into the template.

## Review questions

- What is the input to this process?
- What result is expected?
- Where does an error most often occur?
- Which command or test helps verify the change?

## Next

Next: [Application architecture](../06_application_architecture/README.md).

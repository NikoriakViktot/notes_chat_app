# Student Tasks

## Мінімальне завдання

Додайте поле до `Note`, створіть migration, покажіть поле у detail template.

Критерії:

- migration існує;
- `manage.py check` проходить після виправлення known blockers;
- template не падає.

## Основне завдання

Додайте archive/unarchive flow через service, view, URL і test.

Критерії:

- business logic у `services.py`;
- read query у `selectors.py`;
- access rules протестовані.

## Advanced challenge

Відновіть async HTTP demo повним набором files або виправте Docker build mismatch.

Критерії:

- команда documented;
- tests/checks проходять або blocker чесно описаний;
- application code не ламає існуючі features.

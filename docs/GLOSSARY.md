# Glossary

| Термін | Пояснення |
| --- | --- |
| ASGI | async-capable Python web interface, потрібний для WebSocket і async server runtime |
| Authentication | перевірка, хто користувач |
| Authorization | перевірка, що користувачу дозволено робити |
| Channel layer | pub/sub шар Django Channels для доставки messages між Consumers |
| Consumer | Channels-клас, аналог view для WebSocket-з'єднання |
| CSRF | атака, де чужий сайт змушує browser надіслати небажаний POST |
| Deployment | запуск застосунку на server для реальних користувачів |
| Django app | модуль Django з models, views, forms, templates |
| Django project | package з settings, root urls, wsgi/asgi |
| Form | object для validation і rendering input fields |
| IDOR | Insecure Direct Object Reference, доступ до чужого object через зміну id |
| Middleware | проміжний шар між request і view або view і response |
| Migration | версійний опис зміни database schema |
| Model | Python-клас, що описує table і domain entity |
| ORM | Object Relational Mapper, шар роботи з database через Python objects |
| QuerySet | лінивий object, який описує database query |
| Selector | функція, відповідальна за SELECT/read queries |
| Service | функція, відповідальна за business operation і зміну даних |
| Session | server-side стан, пов'язаний з browser cookie |
| Template | HTML-файл з Django template language |
| Transaction | група DB operations, яка або виконується вся, або відкочується |
| View | обробник HTTP request |
| WebSocket | довге двостороннє connection між browser і server |
| WSGI | класичний sync Python web interface |

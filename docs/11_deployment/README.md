# 11. Deployment

> Deployment - це не git push. Це запуск application stack на server з production settings.

## Що студент вивчить

- яку проблему вирішує цей розділ;
- які поняття треба знати перед роботою з фінальним Django-проєктом;
- які файли відкривати у `notes_chat_app`;
- як перевірити розуміння на практиці.

## Матеріали

| Документ | Призначення |
| --- | --- |
| [Deployment checklist](deployment_checklist.md) | що треба зробити перед production |

## Де це знайти у фінальному проєкті

| Файл | Що подивитися |
| --- | --- |
| `notes_project/settings.py` | DEBUG, ALLOWED_HOSTS, DB, static, security |
| `entrypoint.sh` | ASGI startup draft |

## Мінімальне завдання

Прочитайте головний документ розділу і знайдіть у коді всі згадані файли.

## Основне завдання

Поясніть своїми словами, як ця тема проявляється у поточному проєкті. Не змінюйте код, якщо завдання прямо цього не вимагає.

## Advanced challenge

Знайдіть одну потенційну точку покращення в цій темі і запишіть, які tests або checks мають підтвердити зміну.

## Контрольні питання

- Яка проблема вирішується цим шаром?
- Де межа відповідальності цього шару?
- Який файл є головною точкою входу?
- Яка типова помилка початківця?

## Далі

Далі: [Final project](../12_final_project/README.md).

<!-- restored-full-chapters:start -->

## Повні відновлені глави

Цей блок веде до повних навчальних матеріалів, перенесених з `archive/` без скорочення змісту.

- [11. Деплой Django на Linux](deploy_11_django_on_linux_full.md)
- [12. Nginx, Gunicorn і Uvicorn](deploy_12_nginx_gunicorn_uvicorn_full.md)
- [13. Логи, моніторинг і дебаггінг](deploy_13_logs_monitoring_debugging_full.md)
- [14. Docker: основи](deploy_14_docker_basics_full.md)
- [15. Docker Compose](deploy_15_docker_compose_full.md)
- [16. DevOps workflow](deploy_16_devops_workflow_full.md)
- [17. Kubernetes: огляд](deploy_17_kubernetes_overview_full.md)
- [18. Roadmap і наступні кроки](deploy_18_roadmap_next_steps_full.md)

<!-- restored-full-chapters:end -->

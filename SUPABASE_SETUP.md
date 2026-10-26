# Подключение ReLoop к онлайн-базе Supabase

ReLoop сейчас опубликован как статический GitHub Pages сайт. Чтобы продавцы, объявления и чаты были общими для всех устройств, нужен облачный backend. Эта заготовка использует Supabase (Auth + PostgreSQL + Storage + Realtime).

## 1. Создай проект
1. Открой https://supabase.com/dashboard и создай проект.
2. В Project Settings -> API скопируй Project URL и **publishable/anon key**.
3. Открой SQL Editor и выполни весь файл `supabase/schema.sql`.

## 2. Включи регистрацию
В Authentication -> Providers включи Email. В Authentication -> URL Configuration добавь:
- Site URL: `https://borgilovsana-ship-it.github.io/ReLoop/`
- Redirect URL: `https://borgilovsana-ship-it.github.io/ReLoop/**`

Для тестирования можно выключить подтверждение email, но для публичного запуска лучше оставить подтверждение включённым.

## 3. Фото объявлений
В Storage создай public bucket `listing-images`. Для загрузки файлов добавь политики Storage, разрешающие authenticated-пользователям загружать только в собственную папку. Не разрешай анонимную запись.

## 4. Передать настройки приложению
Нужны только:
- Project URL (выглядит как `https://....supabase.co`)
- Publishable/anon key (длинная публичная строка)

Эти ключи предназначены для клиентского приложения, а безопасность обеспечивается RLS-политиками из SQL. **Никогда не отправляй service_role/secret key.**

## Что подготовлено
`schema.sql` создаёт профили, объявления, диалоги и сообщения, а также включает Row Level Security. Следующий этап — подключить текущие экраны ReLoop к этой базе, сохранив каталог и 3D-модели. Для этого нужны URL и publishable/anon key из твоего проекта Supabase.

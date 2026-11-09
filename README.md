# Широ

Да, это ещё один помодоро-таймер. + задачник + прикольчики ♡

Кошкомальчик на рабочем столе для macOS и Windows: выбираешь задачу, запускаешь фокус и иногда смотришь на глупи анимации.

[Скачать приложение](https://github.com/lilo-shire/shiro-public/releases/latest) · [Лендинг](https://lilo-shire.github.io/shiro-public/) · [Как пользоваться](Инструкция.md) · [Telegram](https://t.me/it_sounds_silly)

## Что умеет

- Таймер работы и отдыха, пауза и продолжение. Длительность меняется в настройках.
- Общий таймер или своё время у каждой задачи.
- Свои разделы, ссылки, перетаскивание задач и блок завершённых.
- Задачи из Markdown-файла, например из Obsidian. Можно дописывать задачи и отмечать готовое. Порядок в Широ хранится отдельно.
- Восемь цветовых схем, три размера окна, русский и английский.
- Звуки уведомлений и фоновая клавиатура со своей громкостью.
- Маскот с реакциями и названием текущей задачи под ним.

## Установка

В [Releases](https://github.com/lilo-shire/shiro-public/releases/latest) лежат три архива. Для Mac выбери Apple Silicon или Intel, распакуй и перенеси «Широ.app» в «Программы». На Windows распакуй папку и запусти Shiro.exe; отдельная установка .NET не нужна.

Сборки без платной подписи издателя, поэтому система может показать предупреждение. Подробности — в [инструкции](Инструкция.md).

Windows-версию пока нужно проверить на настоящем Windows: сборка и проверки логики выполнены на Mac.

## В этой папке

- `work/shiro-pomodoro/` — приложение для Mac, Objective-C / AppKit.
- `work/shiro-windows/` — приложение для Windows, C# / Windows Forms.
- `work/shiro-ui-assets/` — шрифты, звуки и новые прозрачные анимации (`animations/`).
- `assets/` — персонаж и иконка приложения.
- `docs/` — лендинг для GitHub Pages со скринами и анимациями.

## Собрать из исходников

**Mac:** macOS 12+, инструменты командной строки Xcode. Выполни `zsh work/shiro-pomodoro/build.sh`. Приложение появится в `outputs/`. Можно выбрать архитектуру переменной `SHIRO_ARCH=arm64` или `SHIRO_ARCH=x86_64`.

**Windows:** .NET SDK 10. В PowerShell выполни `./work/shiro-windows/build.ps1`. Готовая папка и архив появятся в `outputs/`.

Проверки моделей на Mac: `clang -fobjc-arc -framework Foundation work/shiro-pomodoro/tests.m work/shiro-pomodoro/TimerModel.m work/shiro-pomodoro/TaskModel.m work/shiro-pomodoro/LinkedFile.m -o /tmp/shiro-tests && /tmp/shiro-tests`.

Проверки моделей на любой платформе с .NET 10: `dotnet run --project work/shiro-windows/Tests/Tests.csproj -c Release`.

## Материалы

Шрифты Onest и Unbounded — SIL Open Font License, тексты лицензий рядом с файлами шрифтов. Звук клавиатуры: Desastar, «MacBook / Notebook Keyboard typing sound effect», Pixabay Content License; источник указан в `work/shiro-ui-assets/sounds/CREDITS.txt`. У сторонних материалов сохраняются их собственные условия использования.

Никто не остановит вас от создания своего маскота и кастомного набора реакций. Я даже буду рада — принесите и мне ♡

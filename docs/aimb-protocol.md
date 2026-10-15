# Протокол очков AIMB S2 MAX (по декомпиляции RDGlass 1.2.7)

Источник: официальное приложение `com.rd.rdglass` 1.2.7, декомпилировано jadx 1.5.6. Вендорский SDK — пакеты `com.rd.bluetooth` и `com.artillery.eyeEar`, логика — `com.rd.tengfei.manager.glass.MessageHandleManager`. UI приложения на Flutter (`libapp.so`), но весь протокол — в Java/Kotlin, поэтому виден полностью.

**Проверено на ваших очках:** формат пакета и CRC совпали байт в байт с 4 пакетами, пойманными `probe.bat`. Остальное (Wi-Fi, FTP, фото по BLE) — по коду, проверить скриптом `backend/wifi.bat`.

## Платформа

SDK поддерживает четыре семейства: Realtek, Jieli, BK, XK (MTK). Ваши очки — **BK (чип Beken BK7258)**: их пакеты `12 0F`, `12 0D`, `12 03` — это команды BK, а FTP-логин в коде — `bk7258`.

## BLE GATT

| Сервис / характеристика | Назначение |
|---|---|
| FA00 / **EA01** notify | ответы и события очков (обёртка ED) |
| FA00 / **EA02** write | команды приложения (обёртка ED) |
| FA00 / **EA05** write | SSID для Wi-Fi очков, сырые ASCII-байты |
| FA00 / **EA06** write | пароль Wi-Fi, сырые ASCII-байты |
| 3802 / 4A02 notify+write | второй канал SDK (подписка включается) |

## Формат пакета

```
ED | F | SEQ | CRC | LEN_HI LEN_LO | CMD_HI CMD_LO | PAYLOAD…
F   = 0x40 — последний (или единственный) фрагмент, 0xC0 — будут ещё
SEQ = счётчик 0…255
CRC = CRC-8 по CMD+PAYLOAD: init 0xFF, отражённый полином 0xB8
LEN = длина CMD+PAYLOAD, big-endian
```
Полезная нагрузка больше 192 байт режется на фрагменты, каждый со своим заголовком и той же командой.

## Команды BK (код = CMD)

| Код | Имя | Нагрузка / смысл |
|---|---|---|
| 0x1001 | BKSetSystem | |
| 0x1003 | BKGetBatteryInfo | заряд |
| 0x1004 | BKGetFirmwareInfo | версия прошивки |
| 0x100D | BKTellDeviceInitialized | приложение готово (шлётся после подключения) |
| 0x100E / 0x100F | BKSet/GetVideoConfig | длительность видео |
| 0x1102 | **BKStartAP** | поднять точку доступа (после SSID/пароля) |
| 0x110B | **BKSetApChannel** | `[канал]`, приложение шлёт 6 |
| 0x1120 | BKGetNetworkStatus | режим Wi-Fi, статус, SSID |
| 0x1124 | **BKControlWifi** | `[режим: 0 Client, 1 Hotspot][1 вкл / 0 выкл]` |
| 0x1125 | **BKControlFTP** | `[0 Close, 1 Open, 2 PendingConfirmation]`; ответ 1 — FTP готов |
| 0x1203 | BKMediaChanges | на очках изменились медиафайлы (новое фото/видео) |
| 0x1204 | **BKRequestAI** | очки просят ИИ-сессию; ответ `[resp][vad]`, resp 0 = Allow |
| 0x1206 | BKRecordData | голос с микрофона очков, **Opus** |
| 0x120A | **BKAIIntent** | `[0 Command, 1 VisualQA, 2 PhotoRecognition]` |
| 0x120B | **BKIntentImageData** | **снимок с камеры очков по BLE** (см. ниже) |
| 0x120D | BKGetMediaTrigger | статус съёмки: тип (1 фото, 2 видео, 3 аудио, 4 распознавание, 5 ИИ) и статус |
| 0x120F | BKMediaInterruptionRequest | кнопка фото (наш `12 0F 01`) |
| 0x1210 | BKReliableImageDataTransfer | надёжная передача изображения |
| 0x1212 | BKMediaControl | 1 play, 2 stop, 3 prev, 4 next, 5 vol−, 6 vol+ |

Платформа XK (Wi-Fi Direct, живое видео): 0x1401 XKEnterWiFiMode `[func 0 file/1 OTA/2 LIVE][mode 0 AP/1 P2P/2 STA][channel][ssid…]`, 0x1402 Exit, 0x1403 WiFiStartResult, 0x1404 MediaSDP (URL потока). **У BK живого видео в коде приложения нет.**

## Фото и видео по Wi-Fi (BK) — проверено на очках 15.10.2026

Скрипт `backend/wifi.bat` забрал с очков список из 17 снимков и скачал JPEG 1280×720.

```
1. EA02  BKControlWifi [01 01]              ← Hotspot, включить
   ← BKControlWifi, 0x1126 (подтверждения)
2. EA02  BKGetNetworkStatus
   ← BKGetNetworkStatus: см. разбор ниже — очки САМИ сообщают сеть, пароль и FTP
3. телефон подключается к сети (WifiNetworkSpecifier)
4. EA02  BKControlFTP [01]
5. FTP 192.168.10.1:21, файлы в «/», имена вида 20261014232659.jpeg (дата-время съёмки)
6. EA02  BKControlWifi [01 00]              ← выключить
```

Ответ `BKGetNetworkStatus` на ваших очках:
```
01 01                       режим Hotspot, статус «включено»
C0 A8 0A 01                 шлюз 192.168.10.1 (это очки)
C0 A8 0A 01                 IP
FF FF FF 00                 маска
10 "GE13E1B85B379300"       SSID (16 байт)
0C "E1B85B379300"           пароль (12 байт)
00 15                       порт FTP 21
06 "bk7258"                 логин FTP
06 "123456"                 пароль FTP
```
Сеть постоянна для этих очков: `GE13` + MAC Wi-Fi-модуля (`E1:B8:5B:37:93:00`, он отличается от BLE-адреса), пароль — тот же MAC. Поэтому «меняющаяся точка доступа» — только видимость: приложению достаточно каждый раз спросить её у очков.

Путь «задать SSID/пароль самим + BKStartAP» (`bkSetApChannel`) в RDGlass используется только для обновления старых прошивок; на ваших очках он подтверждается, но сеть не поднимает.

## Фото с камеры очков без Wi-Fi (ИИ-сценарий)

```
очки → BKRequestAI
приложение → BKRequestAI [00 Allow][vad 0/1]   (VAD: где определять конец фразы)
очки → BKRecordData …                           голос, Opus
очки → BKAIIntent [01 VisualQA | 02 PhotoRecognition]
очки → BKIntentImageData: [operation][format][width 2B][height 2B][size…][JPEG…]
```
Это то, что нужно SeeSay: **вопрос голосом и снимок с камеры очков приходят по Bluetooth**, без Wi-Fi и без камеры телефона. Как именно пользователь запускает этот сценарий (долгое нажатие, касание), проверить на очках: поймать `BKRequestAI` в `probe.bat`.

## Что сделать в приложении SeeSay

1. Кодировщик/декодер пакета ED (CRC выше) и отправку команд в EA02 — сейчас приложение только слушает EA01.
2. **ИИ-сценарий по BLE:** ответить Allow на `BKRequestAI`, собрать фрагменты `BKIntentImageData` в JPEG, декодировать Opus → текст (STT на сервере или в телефоне) и отправить снимок с вопросом на бэкенд. Снимок с камеры очков вместо камеры телефона.
3. **Синхронизация галереи по Wi-Fi:** по событию `BKMediaChanges` — шаги 1–8 выше в foreground service (`dataSync`), файлы → Галерея → бэкенд.
4. Живое видео на этих очках (BK) недоступно; это возможность XK-моделей.

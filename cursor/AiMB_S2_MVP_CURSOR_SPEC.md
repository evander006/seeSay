# MVP Specification — AiMB-S2 Max Vision AI & Accessibility

## 1. Назначение проекта

Создать MVP мобильного приложения Flutter для умных очков **AiMB-S2 Max**, ориентированного прежде всего на слабовидящих и незрячих пользователей.

Приложение является связующим звеном между:

- умными очками AiMB-S2 Max;
- пользователем;
- облачным backend на Python/FastAPI с Vision AI/LLM;
- Android Native Layer для BLE, фонового режима, MediaButton/AVRCP и системных событий.

Основной сценарий:

1. Пользователь надевает очки.
2. Приложение устанавливает BLE-соединение.
3. Приложение работает в фоне через Android Foreground Service.
4. Событие физической кнопки/сенсорной панели или действие пользователя инициирует захват изображения.
5. Кадр сжимается и отправляется на backend.
6. Backend анализирует изображение.
7. Ответ возвращается в Flutter.
8. Ответ озвучивается через Android TextToSpeech, желательно через Bluetooth-аудиовыход очков.
9. Все важные состояния приложения дополнительно сообщаются голосом/звуковым сигналом.
10. Интерфейс полностью доступен через TalkBack и Flutter Semantics.

---

# 2. Источник требований

Основной технический документ описывает приложение как интеллектуальный хаб между AiMB-S2 Max, пользователем и облачным FastAPI + LLM Vision backend. Он требует фоновой BLE-связи, захвата кадров, отправки запросов серверу и озвучивания ответов через динамики очков. fileciteturn0file0L5-L13

Архитектура должна разделять Android Native Layer на Kotlin и Flutter UI/Logic Layer на Dart. fileciteturn0file0L15-L23

---

# 3. Scope MVP

## Обязательно реализовать

### 3.1. Главный экран

Главный экран должен быть максимально простым и состоять из 2–3 крупных интерактивных зон.

Минимальные действия:

- **Сделать фото / Что передо мной?**
- **Прочитать текст**
- **Повторить последний ответ**

Дополнительно:

- состояние Bluetooth;
- состояние подключения очков;
- состояние сети;
- статус последнего запроса;
- кнопка/зона настроек.

### 3.2. Accessibility

Все интерактивные элементы обязаны использовать `Semantics`.

Примеры:

```dart
Semantics(
  label: 'Сделать фото',
  hint: 'Двойное нажатие для активации',
  button: true,
  child: ...
)
```

Для TalkBack Flutter должен предоставлять:

- понятный `label`;
- понятный `hint`;
- корректный тип элемента;
- корректное состояние;
- отсутствие бессмысленных декоративных элементов в accessibility tree.

### 3.3. Audio-first

Приложение должно иметь единый сервис:

```text
AccessibilityAudioService
```

Он отвечает за:

- TextToSpeech;
- beep-сигналы;
- прерывание текущей озвучки;
- повтор последнего ответа;
- очередность сообщений;
- выбор языка;
- управление скоростью речи.

Любое важное состояние должно иметь голосовое подтверждение:

- очки подключены;
- очки отключены;
- Bluetooth недоступен;
- сеть недоступна;
- начинаю анализ;
- анализ завершён;
- ошибка;
- текст распознан;
- команда выполнена.

Техническое задание явно требует Audio-First интерфейс: изменение состояния приложения должно дублироваться голосом или звуковыми сигналами. fileciteturn0file0L145-L150

### 3.4. Custom touch-to-speech

Нужен отдельный механизм для работы даже без TalkBack.

Пользователь может:

- нажать;
- удерживать;
- провести пальцем по интерактивной области.

При длительном нажатии или навигации пальцем приложение может озвучить:

```text
Сделать фото. Двойное нажатие для активации.
```

Важно:

- этот механизм не должен ломать стандартные жесты Flutter;
- TalkBack остаётся штатным механизмом accessibility;
- custom TTS является дополнительным fallback/режимом;
- не должно быть двойной озвучки одного и того же действия при активном TalkBack.

Для MVP допускается реализовать custom touch exploration только на уровне крупных зон главного экрана.

---

# 4. Визуальные требования

Основной UI:

- фон: `#000000`;
- текст: белый или ярко-жёлтый;
- минимальный размер основного текста: 22sp/pt;
- большие кнопки;
- высокий контраст;
- минимум мелких элементов;
- минимум декоративных компонентов;
- portrait как основной MVP-режим;
- возможность дальнейшего расширения до landscape.

Эти требования непосредственно указаны в техническом задании. fileciteturn0file0L155-L164

---

# 5. Архитектура

Использовать:

```text
Clean Architecture
+
Feature-first structure
+
Cubit/Bloc
+
Repository pattern
+
Dependency Injection
+
Native Android bridge
```

Рекомендуемая структура:

```text
lib/
├── app/
│   ├── app.dart
│   ├── router/
│   ├── theme/
│   └── di/
│
├── core/
│   ├── accessibility/
│   │   ├── accessibility_audio_service.dart
│   │   ├── semantics_builder.dart
│   │   └── touch_exploration_service.dart
│   │
│   ├── audio/
│   ├── bluetooth/
│   ├── camera/
│   ├── errors/
│   ├── network/
│   ├── storage/
│   ├── platform/
│   ├── permissions/
│   └── utils/
│
├── features/
│   ├── home/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── glasses/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── vision/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── ocr/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   └── settings/
│
└── main.dart
```

---

# 6. State management

Использовать `flutter_bloc` / Cubit.

Минимальные Cubit:

```text
ConnectionCubit
VisionCubit
OcrCubit
AccessibilityCubit
AppCubit
```

### ConnectionState

```text
disconnected
connecting
connected
error
```

### VisionState

```text
idle
capturing
uploading
processing
success
error
```

### OcrState

```text
idle
capturing
uploading
processing
success
error
```

Не хранить бизнес-логику непосредственно в Widgets.

---

# 7. Domain layer

Определить use cases:

```text
ConnectGlasses
DisconnectGlasses
CaptureFrame
AnalyzeFrame
ReadText
SpeakText
StopSpeech
RepeatLastResponse
SaveLastResponse
GetLastResponses
```

Главные сценарии:

```text
CaptureFrame
    ↓
CompressFrame
    ↓
AnalyzeFrame
    ↓
SaveResponse
    ↓
SpeakResponse
```

и:

```text
CaptureFrame
    ↓
CompressFrame
    ↓
ReadText
    ↓
SaveResponse
    ↓
SpeakResponse
```

---

# 8. Backend API

## Анализ изображения

```http
POST /api/v1/analyze-frame
Content-Type: multipart/form-data
```

Поля:

```text
file: image/jpeg
prompt: optional string
latitude: optional float
longitude: optional float
```

Кадр:

- JPEG;
- максимум 1080p;
- quality 80–85%.

Пример ответа:

```json
{
  "status": "success",
  "text_response": "Перед вами вход в аптеку. Дверь находится справа, перед ней две ступени.",
  "execution_time_ms": 1100
}
```

Эти endpoint и формат запроса/ответа заданы в ТЗ. fileciteturn0file0L91-L122

## OCR

```http
POST /api/v1/read-text
Content-Type: multipart/form-data
```

Поле:

```text
file: image/jpeg
```

Ответ:

```json
{
  "status": "success",
  "raw_text": "Аптека Вита. Режим работы с 8:00 до 21:00."
}
```

Endpoint и формат OCR также определены в ТЗ. fileciteturn0file0L128-L142

---

# 9. Networking

Рекомендуемые библиотеки:

```yaml
dio:
  ^5.x

connectivity_plus:
  ^6.x

internet_connection_checker_plus:
  ^2.x
```

Использовать `Dio` для:

- REST;
- multipart upload;
- timeout;
- interceptor;
- централизованной обработки ошибок.

Создать:

```text
ApiClient
VisionApi
```

Пример:

```dart
abstract interface class VisionRemoteDataSource {
  Future<AnalyzeFrameResponse> analyzeFrame({
    required File image,
    String? prompt,
    double? latitude,
    double? longitude,
  });

  Future<ReadTextResponse> readText({
    required File image,
  });
}
```

---

# 10. Bluetooth architecture

Bluetooth разделить на два независимых канала.

## BLE

BLE используется для управления очками и получения событий камеры.

Сервис:

```text
0000fa00-0000-1000-8000-00805f9b34fb
```

Notify characteristic:

```text
0000ea01-0000-1000-8000-00805f9b34fb
```

CCCD:

```text
0x2902
```

Для notifications записывать:

```text
0x0100
```

Это соответствует ТЗ. fileciteturn0file0L46-L56

## Classic Bluetooth / AVRCP

Использовать для событий сенсорной панели:

```text
MEDIA_PLAY_PAUSE
VOLUME_UP
VOLUME_DOWN
```

Android Native должен использовать `BroadcastReceiver` / `MediaButtonReceiver`. fileciteturn0file0L72-L83

---

# 11. BLE packet parser

Создать:

```text
BlePacketParser
```

Проверять Magic Header:

```text
ED 40
```

MVP parser должен распознавать:

```text
ED 40 … 12 0F 01
    -> photo trigger

ED 40 … 12 0D 01 01
    -> capture started

ED 40 … 12 0D 04 01
    -> double tap

ED 40 … 12 0D 02 02
    -> video initialization

ED 40 … 12 0D 02 01
    -> recording

ED 40 … 12 0D 00 00
    -> idle/end
```

Эти packet patterns приведены в ТЗ. fileciteturn0file0L58-L70

Parser должен быть отдельным pure Dart компонентом и покрываться unit-тестами.

---

# 12. Android Native Layer

Android Native Layer реализовать на Kotlin.

Причины:

- BLE;
- Foreground Service;
- MediaButtonReceiver;
- системные события;
- background execution;
- Android TextToSpeech;
- audio routing.

ТЗ требует постоянный Android Foreground Service с persistent notification, чтобы ОС не уничтожала BLE-соединение в фоне. fileciteturn0file0L85-L89

Flutter ↔ Kotlin:

```text
MethodChannel
EventChannel
```

## MethodChannel

Использовать для команд:

```text
connectGlasses
disconnectGlasses
startCapture
stopCapture
speak
stopSpeaking
setSpeechRate
getConnectionState
```

## EventChannel

Использовать для событий:

```text
bleConnectionChanged
blePacketReceived
mediaButtonEvent
batteryChanged
```

---

# 13. Foreground Service

Создать Kotlin service:

```text
GlassesForegroundService
```

Service должен:

1. запуститься после подключения очков;
2. создать notification channel;
3. показать persistent notification;
4. поддерживать BLE connection;
5. отправлять события Flutter;
6. корректно восстанавливать соединение;
7. освобождать ресурсы при disconnect.

Notification:

```text
AiMB-S2 Max подключены
```

или:

```text
AiMB-S2 Max: выполняется подключение
```

---

# 14. TextToSpeech

Основной сервис:

```text
AccessibilityAudioService
```

API:

```dart
Future<void> speak(
  String text, {
  bool interrupt = true,
});

Future<void> stop();

Future<void> repeatLast();

Future<void> dispose();
```

На Android использовать системный TextToSpeech.

Приоритет:

```text
Очки Bluetooth audio output
        ↓
Android audio output
```

Не создавать отдельный TTS engine во Flutter для каждого запроса.

Должен существовать один lifecycle-managed экземпляр.

---

# 15. Audio queue

Использовать очередь сообщений.

Приоритеты:

```text
CRITICAL
HIGH
NORMAL
LOW
```

Например:

```text
Ошибка соединения -> HIGH
Получен ответ AI -> NORMAL
Подсказка интерфейса -> LOW
```

Если пользователь нажал кнопку повторного ответа:

```text
stop current speech
speak last response
```

Если пришло критическое сообщение:

```text
stop current speech
speak critical message
```

---

# 16. Haptic feedback

Использовать:

```yaml
haptic_feedback:
```

или стандартный Flutter `HapticFeedback`.

Типы:

```text
tap
success
error
connection
capture
```

Разная длительность вибрации должна обозначать разные состояния.

ТЗ требует haptic feedback при физических действиях. fileciteturn0file0L152-L153

---

# 17. Camera

Рекомендуемая библиотека:

```yaml
camera:
```

Pipeline:

```text
Camera
 ↓
Capture JPEG
 ↓
Resize if necessary
 ↓
Compress JPEG
 ↓
Temporary file
 ↓
Multipart upload
```

Ограничения:

```text
max 1080p
JPEG
quality 80–85
```

Не держать несколько больших кадров в RAM одновременно.

---

# 18. GPS

Использовать:

```yaml
geolocator:
```

GPS является optional.

Передавать координаты:

```text
latitude
longitude
```

только если разрешение получено и координаты доступны.

Если GPS недоступен — запрос всё равно должен выполняться.

---

# 19. Local storage

Для MVP использовать:

```yaml
shared_preferences:
```

для:

- настроек;
- последнего устройства;
- speech rate;
- выбранного языка;
- accessibility mode;
- последнего connection state.

Для последних 10 ответов использовать:

```yaml
hive:
```

или `sqflite`.

Предпочтительно `Hive` для простоты MVP.

Модель:

```dart
class SavedResponse {
  final String id;
  final String text;
  final DateTime createdAt;
  final ResponseType type;
}
```

Хранить максимум:

```text
10 responses
```

При добавлении 11-го удалять самый старый.

ТЗ требует кэшировать настройки подключения и последние 10 ответов. fileciteturn0file0L166-L177

---

# 20. Permissions

Android permissions должны обрабатываться централизованно.

Проверять:

```text
Bluetooth
Bluetooth Scan
Bluetooth Connect
Camera
Location
Notifications
Microphone — только если реально нужен
```

Не запрашивать разрешение заранее без необходимости.

Запрашивать permission непосредственно перед использованием функции.

---

# 21. Accessibility architecture

Создать reusable widget:

```dart
class AccessibleAction extends StatelessWidget
```

API:

```dart
AccessibleAction(
  label: 'Сделать фото',
  hint: 'Двойное нажатие для активации',
  onTap: ...,
  child: ...,
)
```

Внутри:

```text
Semantics
+
Focus
+
GestureDetector
+
HapticFeedback
+
optional custom TTS
```

## Важное правило

`Semantics` является основным механизмом accessibility.

Custom touch-to-speech не должен заменять TalkBack.

---

# 22. Custom touch exploration

Создать:

```text
TouchExplorationService
```

Алгоритм MVP:

```text
PointerDown
    ↓
find interactive semantic zone
    ↓
start timer 600–800 ms
    ↓
если PointerUp раньше таймера:
    обычный tap
    ↓
если timer завершился:
    speak(label + hint)
    ↓
PointerMove:
    если перешли в другую accessibility zone
        speak(new zone)
```

Защита от повторной озвучки:

```text
lastSpokenElementId
lastSpokenTimestamp
```

Не повторять один и тот же label чаще заданного debounce-интервала.

---

# 23. Home Screen MVP

Экран:

```text
┌──────────────────────────────┐
│ AiMB-S2 Max                   │
│ ● Подключены                  │
├──────────────────────────────┤
│                              │
│       СДЕЛАТЬ ФОТО            │
│      «Что передо мной?»       │
│                              │
├──────────────────────────────┤
│                              │
│       ПРОЧИТАТЬ ТЕКСТ         │
│                              │
├──────────────────────────────┤
│                              │
│       ПОВТОРИТЬ ОТВЕТ         │
│                              │
├──────────────────────────────┤
│ Настройки                     │
└──────────────────────────────┘
```

Все зоны огромные.

Каждая зона имеет:

```text
Semantics.label
Semantics.hint
onTap
haptic feedback
custom TTS support
```

---

# 24. Screen states

Главный экран должен визуально и голосом показывать:

```text
Очки не подключены
Подключение...
Очки подключены
Готово
Захват изображения...
Отправка...
Анализ...
Готово
Ошибка
```

Не использовать маленькие snackbar как единственный способ уведомления.

---

# 25. Error handling

Создать typed exceptions:

```text
BluetoothException
CameraException
NetworkException
ApiException
PermissionException
SpeechException
```

Все ошибки должны проходить через единый mapper:

```text
Exception
 ↓
Failure
 ↓
User-friendly message
 ↓
TTS
+
UI
```

Пример:

```text
NetworkException
→ «Нет подключения к интернету. Попробуйте ещё раз.»
```

---

# 26. Offline behavior

В MVP при отсутствии сети:

1. не отправлять запрос;
2. сообщить пользователю голосом;
3. сохранить последний доступный ответ;
4. оставить приложение работоспособным;
5. после восстановления сети обновить connection state.

Автоматическая повторная отправка не должна приводить к бесконечным retry.

Использовать:

```text
exponential backoff
```

например:

```text
1s → 2s → 4s → 8s
```

с ограничением количества попыток.

---

# 27. Dependency Injection

Использовать:

```yaml
get_it:
```

Регистрация:

```text
ApiClient
VisionRepository
OcrRepository
AccessibilityAudioService
GlassesRepository
CameraService
LocationService
StorageService
```

Cubit получать через DI, а не создавать зависимости непосредственно внутри UI.

---

# 28. Routing

Использовать:

```yaml
go_router:
```

MVP routes:

```text
/
 /home
 /settings
 /history
```

Но приложение должно быть usable даже без сложной навигации.

Главный сценарий должен выполняться с одного экрана.

---

# 29. Recommended dependencies

Пример `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  flutter_bloc: ^9.0.0
  dio: ^5.0.0
  get_it: ^8.0.0

  camera: ^0.11.0
  geolocator: ^13.0.0

  connectivity_plus: ^6.0.0
  internet_connection_checker_plus: ^2.0.0

  flutter_blue_plus: ^1.0.0

  hive: ^2.2.3
  hive_flutter: ^1.1.0

  permission_handler: ^12.0.0
  haptic_feedback: ^0.5.0

  go_router: ^16.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter

  bloc_test: ^10.0.0
  mocktail: ^1.0.0
```

Версии не считать строгими: Cursor должен проверить актуальную совместимость версий перед установкой.

---

# 30. Native Android libraries

Для Kotlin:

```text
Android Bluetooth APIs
BluetoothGatt
BluetoothGattCallback
BluetoothAdapter
BluetoothManager

Foreground Service APIs

MediaSession / MediaButtonReceiver

Android TextToSpeech
AudioManager
```

Не использовать Flutter package для функций, которые требуют надежного Android background execution, если Android Native API решает задачу стабильнее.

---

# 31. Testing

Обязательно написать:

## Unit tests

```text
BlePacketParser
ResponseMapper
AccessibilityAudioQueue
RetryPolicy
ResponseStorage
```

## Cubit tests

```text
VisionCubit
OcrCubit
ConnectionCubit
```

## Widget tests

Проверить:

- Semantics labels;
- Semantics hints;
- крупные кнопки;
- правильные состояния;
- отсутствие network-dependent поведения в widget tests.

## Integration

Минимальный smoke test:

```text
launch
→ home
→ tap photo
→ mocked API
→ result
→ TTS service called
```

---

# 32. Logging

Добавить structured logging.

Каждый важный event:

```text
timestamp
level
message
screen
action
error
```

Логировать:

```text
app started
BLE connected
BLE disconnected
photo trigger
camera capture
API request
API success
API error
TTS started
TTS finished
TTS error
permission denied
uncaught exception
```

Не логировать персональные данные, содержимое изображений или чувствительные данные пользователя.

---

# 33. Security

Не хранить API secrets в исходниках.

Использовать:

```text
.env
```

для dev configuration.

Не отправлять GPS без разрешения.

Не логировать:

```text
images
tokens
passwords
personal identifiers
```

---

# 34. MVP implementation order

Cursor должен реализовать проект именно в таком порядке:

### Phase 1

Flutter skeleton:

```text
Clean Architecture
DI
Router
Theme
Home screen
```

### Phase 2

Accessibility:

```text
Semantics
AccessibleAction
AccessibilityAudioService
Haptic feedback
Custom touch-to-speech
```

### Phase 3

Camera:

```text
CameraService
capture
compress
temporary file
```

### Phase 4

Backend:

```text
Dio
Vision API
OCR API
repositories
Cubit
```

### Phase 5

Android Native:

```text
MethodChannel
EventChannel
Foreground Service
BLE manager
MediaButtonReceiver
TTS
```

### Phase 6

Integration:

```text
BLE photo trigger
→ camera
→ API
→ response
→ TTS
```

### Phase 7

Offline/cache/history.

### Phase 8

Tests + README.

---

# 35. Definition of Done

MVP считается готовым, если:

- проект запускается на Android;
- главный экран полностью доступен через TalkBack;
- каждый интерактивный элемент имеет понятный label/hint;
- custom audio accessibility работает без TalkBack;
- камера делает JPEG;
- JPEG сжимается до допустимого размера;
- `/api/v1/analyze-frame` вызывается корректно;
- `/api/v1/read-text` вызывается корректно;
- ответ backend озвучивается;
- последние 10 ответов сохраняются;
- Bluetooth connection state отображается;
- BLE packet parser работает на тестовых пакетах;
- Foreground Service запускается;
- MediaButton события доходят до Flutter;
- ошибки озвучиваются;
- сеть без подключения обрабатывается;
- проект имеет README;
- код разделён по слоям;
- бизнес-логика не находится в Widgets;
- есть unit/widget тесты.

---

# 36. Что НЕ делать в MVP

Не реализовывать без необходимости:

- полноценную регистрацию;
- сложный onboarding;
- социальные функции;
- сложный дизайн;
- видеопоток;
- WebSocket streaming;
- сложную синхронизацию;
- облачное хранение истории;
- полноценную карту;
- распознавание лиц;
- автономную LLM на устройстве.

REST API для одиночного кадра является MVP-приоритетом; WebSocket оставить архитектурно расширяемым, поскольку ТЗ предусматривает его для потокового аудио/видео. fileciteturn0file0L91-L96

---

# 37. Требование к Cursor

Перед написанием кода Cursor должен:

1. проанализировать текущий репозиторий;
2. не удалять существующую рабочую функциональность без необходимости;
3. определить текущие версии Flutter/Dart/Gradle/Android SDK;
4. проверить совместимость выбранных packages;
5. составить краткий список изменений;
6. затем реализовывать по фазам;
7. после каждого крупного этапа запускать:
   - `flutter analyze`;
   - `flutter test`;
8. исправлять найденные ошибки;
9. не оставлять TODO вместо MVP-функций;
10. документировать Native ↔ Flutter protocol.

Если реальное устройство AiMB-S2 Max недоступно, создать:

```text
MockGlassesRepository
MockBlePacketStream
MockVisionApi
MockTtsService
```

чтобы весь пользовательский сценарий можно было продемонстрировать без очков.

---

# 38. Cursor coding principles

Использовать:

- SOLID;
- dependency inversion;
- immutable state;
- typed failures;
- small classes;
- repository interfaces;
- DTO отдельно от domain models;
- отсутствие business logic во Flutter Widgets.

Предпочтение:

```text
Feature → UseCase → Repository → DataSource
```

а не:

```text
Widget → Dio
```

---

# 39. Demo scenario

Для демонстрации MVP:

```text
1. Запустить приложение.
2. Приложение голосом говорит:
   «Приложение готово. Очки не подключены.»

3. Подключить mock/реальные очки.

4. Приложение говорит:
   «Очки подключены.»

5. Нажать «Сделать фото».

6. Приложение говорит:
   «Делаю снимок.»

7. Фото отправляется на backend.

8. Backend отвечает:
   «Перед вами вход в аптеку. Дверь справа. Перед дверью две ступени.»

9. TTS озвучивает ответ.

10. Нажать «Повторить ответ».

11. Ответ воспроизводится снова.

12. Провести пальцем по кнопке.

13. Приложение говорит:
   «Сделать фото. Двойное нажатие для активации.»

14. Включить TalkBack.

15. Проверить, что Semantics корректно озвучиваются TalkBack.
```

---

# 40. Итоговая архитектурная схема

```text
                    ┌─────────────────────┐
                    │     AiMB-S2 Max      │
                    │                     │
                    │ BLE / AVRCP / Audio │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │ Android Native      │
                    │ Kotlin              │
                    │                     │
                    │ BLE Manager         │
                    │ Foreground Service  │
                    │ MediaButtonReceiver │
                    │ Android TTS         │
                    └──────────┬──────────┘
                               │
                     MethodChannel
                     EventChannel
                               │
                    ┌──────────▼──────────┐
                    │ Flutter Core        │
                    │                     │
                    │ Cubit               │
                    │ UseCases            │
                    │ Repositories        │
                    │ Accessibility       │
                    └───────┬───────┬─────┘
                            │       │
                   ┌────────▼─┐   ┌─▼────────┐
                   │ Camera   │   │ Location │
                   └──────────┘   └──────────┘
                            │
                    ┌───────▼────────┐
                    │ Dio / REST      │
                    └───────┬────────┘
                            │
                    ┌───────▼────────────┐
                    │ FastAPI + Vision AI │
                    │                     │
                    │ analyze-frame       │
                    │ read-text           │
                    └─────────────────────┘
```

# 41. Главное правило проекта

**Accessibility является не дополнительной функцией, а одним из центральных слоёв архитектуры.**

Каждое действие должно быть доступно одновременно через:

```text
Touch
+
TalkBack/Semantics
+
Voice/TTS
+
Haptic feedback
+
Physical glasses controls
```

При конфликте между визуальным удобством и accessibility приоритет отдаётся accessibility.

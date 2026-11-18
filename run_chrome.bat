@echo off
flutter run -d chrome --web-port=3000 --web-hostname=127.0.0.1 --dart-define-from-file=.env.local
pause

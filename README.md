# tft_ladder_race

Privates Flutter-Web-Dashboard fuer TFT Ladder Race mit Firebase-Initialisierung und Auth-Grundsetup.

Die primaere Zielplattform ist aktuell der Browser. Mobile und Desktop-Plattformen bleiben als Flutter-Targets erhalten, sind aber nicht der aktuelle Entwicklungsfokus.

## Enthalten

- Flutter App Grundstruktur
- Firebase Initialisierung ueber `lib/firebase_options.dart`
- Firebase Auth Grundsetup (E-Mail/Passwort und anonym)
- Auth Gate (eingeloggt/nicht eingeloggt)

## Schnellstart

1. Abhaengigkeiten installieren:

	```bash
	flutter pub get
	```

2. App starten:

	```bash
	flutter run -d chrome
	```

Alternativ in VS Code die Run-Konfiguration `tft_ladder_race (Web)` starten. Sie verwendet Chrome automatisch.

## Als Template fuer neue Projekte nutzen

Ja, das ist sinnvoll. Du kannst dieses Repo als Starter behalten und pro neuem Projekt nur Firebase neu verbinden.

1. Repo klonen.
2. Neues Firebase-Projekt in der Console erstellen.
3. Neue Firebase-Konfiguration erzeugen:

	```bash
	dart pub global activate flutterfire_cli
	dart pub global run flutterfire_cli:flutterfire configure --project=<DEIN_NEUES_FIREBASE_PROJEKT_ID> --platforms=android,ios,web,macos,windows --yes
	```

	Oder unter Windows kurz:

	```powershell
	.\scripts\reconfigure_firebase.ps1 -ProjectId <DEIN_NEUES_FIREBASE_PROJEKT_ID>
	```

4. Fertig: `lib/firebase_options.dart` und Plattform-Konfigurationen sind auf das neue Backend umgestellt.

## Wichtige Dateien

- `lib/main.dart`: Firebase-Initialisierung
- `lib/app/app.dart`: App-Root
- `lib/features/auth/data/auth_service.dart`: Auth-Zugriff
- `lib/features/auth/presentation/auth_gate.dart`: Routing nach Auth-Status
- `lib/features/auth/presentation/sign_in_screen.dart`: Login-Startseite
- `lib/features/home/presentation/home_screen.dart`: Beispielseite nach Login

## Firebase Auth aktivieren

In der Firebase Console unter Authentication -> Sign-in method aktivieren:

- Email/Password
- Anonymous (optional, wenn du den Fallback-Button nutzen willst)

## Copilot Workflow fuer neue Projekte

Ja, mit dieser Doku kannst du das beim naechsten Mal praktisch 1:1 wiederholen.

Wichtig: Das Firebase-Projekt selbst wird in der Regel in der Firebase Console angelegt. Danach kann Copilot das Flutter-Projekt auf dieses Backend verdrahten.

### Welche Infos Copilot von dir braucht

- Zielpfad des neuen Projekts (lokaler Ordner)
- Projektname fuer Flutter (z. B. `my_new_app`)
- Firebase Project ID (z. B. `my-new-app-prod`)
- Gewuenschte Plattformen (z. B. android,ios,web,macos,windows)
- Ob Auth-Basis enthalten sein soll (E-Mail/Passwort, anonym oder beides)

### Copy-Paste Prompt fuer Copilot

```text
Erzeuge mir in diesem Ordner ein neues Flutter-Starterprojekt mit Firebase-Anbindung.

Rahmen:
- Projektpfad: <PFAD>
- Flutter Projektname (snake_case): <PROJEKTNAME>
- Firebase Project ID: <FIREBASE_PROJECT_ID>
- Plattformen: <PLATTFORMEN>
- Auth Setup: <email_password | anonymous | beides>

Bitte:
1) Flutter App erzeugen
2) Firebase mit flutterfire configure verbinden
3) Auth-Grundsetup anlegen (Login/Register/Logout je nach Auswahl)
4) README mit den finalen Schritten aktualisieren
5) flutter analyze und flutter test ausfuehren

Wenn dir Infos fehlen, frag mich gezielt danach.
```

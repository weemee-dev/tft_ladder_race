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

## Feste Benutzer anlegen und einloggen

Damit nur du und deine drei Freunde Zugriff haben, werden die Konten einmalig in
der Firebase Console angelegt. Die App enthält absichtlich keine Registrierung
und keine Passwörter.

1. Öffne in der Firebase Console `Authentication` -> `Sign-in method`.
2. Aktiviere `Email/Password` und speichere.
3. Öffne `Authentication` -> `Users` -> `Add user`.
4. Lege dort vier E-Mail-/Passwort-Konten an, zum Beispiel eines pro Freund.
5. Starte die App mit `flutter run -d chrome` und melde dich mit einem dieser
	Konten an.

Der Button `Oder anonym anmelden` ist nur für lokale Tests gedacht. Wenn du ihn
nicht brauchst, kannst du `Anonymous` in Firebase deaktiviert lassen. Falls der
Login mit `operation-not-allowed` scheitert, ist `Email/Password` in Schritt 2
noch nicht aktiviert oder Firebase wurde mit dem falschen Projekt verbunden.

## Firebase Auth aktivieren

Für den festen Login ist nur dieser Provider erforderlich:

- Email/Password

Anonymous bleibt optional und wird nur vom Test-Button verwendet.

## Riot API sicher mit Firebase verbinden

Der Riot-Key gehört nicht in Flutter, `firebase_options.dart`, Firestore oder
Git. Die Cloud Function liest ihn aus dem Firebase Secret Manager. Auch die
Riot-Abfragen laufen ausschließlich in `functions/`, nie im Browser.

### Einmalige Einrichtung

Voraussetzungen: Firebase CLI, Node.js 20 und ein Firebase-Projekt im Blaze-
Tarif. Die Function läuft in `europe-west1` (Belgien), während die Riot-API über
die EU-Routen `europe` und `euw1` angesprochen wird. Scheduled Cloud Functions
benötigen den Blaze-Tarif, weil Cloud Scheduler verwendet wird.

1. Firebase CLI anmelden und das Projekt auswählen:

	 ```powershell
	 firebase login
	 firebase use tft-ladder-race
	 ```

2. Den Riot-Key interaktiv im Firebase Secret Manager hinterlegen:

	 ```powershell
	 firebase functions:secrets:set RIOT_API_KEY
	 ```

	 Den Key niemals in den Chat, in den Flutter-Code oder in eine versionierte
	 Datei eintragen. Falls der Key bereits öffentlich geteilt wurde, im Riot
	 Developer Portal sofort einen neuen Key erzeugen.

3. In Firestore das Dokument `race_config/players` anlegen. Das Feld `players`
	 ist ein Array mit exakt vier Einträgen. Für EUW sieht die Struktur so aus:

	 ```json
	 {
		 "players": [
			 {
				 "id": "friend-1",
				 "name": "Mango",
				 "gameName": "RiotName1",
				 "tagLine": "EUW",
				 "startLeaguePoints": 0
			 },
			 {
				 "id": "friend-2",
				 "name": "Kira",
				 "gameName": "RiotName2",
				 "tagLine": "EUW",
				 "startLeaguePoints": 0
			 },
			 {
				 "id": "friend-3",
				 "name": "Rex",
				 "gameName": "RiotName3",
				 "tagLine": "EUW",
				 "startLeaguePoints": 0
			 },
			 {
				 "id": "friend-4",
				 "name": "Nova",
				 "gameName": "RiotName4",
				 "tagLine": "EUW",
				 "startLeaguePoints": 0
			 }
		 ]
	 }
	 ```

	 `gameName` und `tagLine` müssen exakt der Riot-ID entsprechen. Der Wert
	 `startLeaguePoints` wird beim ersten Placement Game festgehalten; aktuell
	 muss er zunächst manuell eingetragen werden. `lpGain` wird danach von der
	 Function als aktuelles LP minus Start-LP berechnet.

4. Function und Firestore-Regeln deployen:

	 ```powershell
	 Push-Location functions
	 npm install
	 npm run build
	 Pop-Location
	 firebase deploy --only functions,firestore
	 ```

	 Nach dem Deploy wird `refreshLadderData` automatisch ungefähr stündlich
	 ausgeführt und schreibt nach `ladder_data/current`.

Die App liest dieses Dokument nur für angemeldete Firebase-Nutzer. Schreibzugriff
auf `ladder_data` und `race_config` ist durch `firestore.rules` gesperrt; die
Function verwendet für ihre Schreibvorgänge das Admin SDK und ist davon nicht
betroffen.

## GitHub Actions

Das Repository enthält drei getrennte Workflows unter `.github/workflows/`:

- `deploy.yml`: baut und deployed die Flutter-Web-App zu Firebase Hosting.
- `deploy-functions.yml`: baut und deployed `refreshLadderData`.
- `run-ladder-refresh.yml`: startet den Cloud-Scheduler-Job manuell.

Für `deploy.yml` und `deploy-functions.yml` wird das GitHub-Secret
`FIREBASE_TOKEN` benötigt. Es kann lokal mit folgendem Befehl erzeugt werden:

```powershell
firebase login:ci
```

Für `run-ladder-refresh.yml` wird zusätzlich das Secret `GCP_SA_KEY` benötigt.
Darin liegt der JSON-Schlüssel eines Google-Service-Accounts mit mindestens der
Rolle `Cloud Scheduler Job Runner` im Projekt `tft-ladder-race`. Der Account
muss außerdem den Scheduler-Job in `europe-west1` ausführen dürfen.

Der Function-Deploy läuft automatisch bei Änderungen unter `functions/` auf
`main` und kann zusätzlich manuell gestartet werden. Der Scheduler-Workflow
läuft ausschließlich manuell über `Actions` -> `Run Ladder Refresh` -> `Run
workflow`.


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

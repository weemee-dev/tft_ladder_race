# TFT Ladder Race - Projekt-Dokumentation

Dieses Dokument dient als zentrale Wissensquelle für die KI-gestützte Entwicklung der TFT Ladder Race App (Flutter & Firebase).

## 1. Projekt-Übersicht
*   **Ziel:** Eine unterhaltsame, private App für ein TFT-Ladder-Race zwischen 4 Freunden.
*   **Kern-Features:**
    *   Countdown bis 10.09., 23:59 Uhr (MESZ).
    *   Zwei Kategorien:
        1. Höchste Elo (Live-Ranking).
        2. Meiste LP Gain (Differenz zwischen Start und Finish).
    *   "Hype-Faktoren" & Humor: Statistiken, Streaks, Fun-Facts ("Schandpfähle").

## 2. Architektur-Vorgaben
*   **Frontend:** Flutter.
*   **Backend:** Firebase Firestore.
*   **API-Handling:**
    *   Verwendung von Riot API (TFT).
    *   **Rate-Limit Management:** Cloud Function führt Scheduled Cron-Job (1x pro Stunde) aus.
    *   Ergebnisse werden als JSON in Firestore gespeichert.
    *   Flutter-App nutzt `StreamBuilder`, um auf Firestore-Updates zu reagieren.

## 3. Design-System (Neon-Hextech)
*   **Farbpalette:**
    *   Hintergrund: Tiefes Anthrazit (`#161B22`).
    *   Gold (für Leader), Hextech-Blau (für Platz 2-3), Neon-Rot/Orange (für Streaks/Warnungen).
*   **UI-Komponenten:**
    *   **Header:** Countdown-Timer + Regel-Shortcuts.
    *   **Podest:** Visuelle Rangliste.
    *   **Spieler-Karten:**
        *   Anzeige: Name, Titel, LP-Gain (`▲` / `▼`), Elo-Icon.
        *   Streak-Indikator: Feuer-Emoji + Zahl (z.B. 🔥 4).
        *   Match-Historie: Bunte Kreise (Grün für Top 4, Rot für Bot 4).
    *   **Wall of Shame:** Dynamisches Karussell für humorvolle Statistiken.

## 4. Statistische Auswertung (API-Integration)
*   **Datenquellen:** `tft-match/v1/matches/{matchId}`.
*   **Identifikation von Comps (Entlarvung des "One-Trick-Pony"):**
    *   Analyse von `units` (Champions) und `traits` (Synergien).
    *   Tracking der Häufigkeit über 15-20 Matches.
*   **Fun-Statistiken:**
    *   "Fast 8th Enjoyer": Häufigkeit Platz 1 oder 8.
    *   "Der Zinn-Soldat": Gold-Management.
    *   "Der Grinder": Spielanzahl/Zeit.

## 5. Implementierungshinweise für Copilot
*   **Widget-Struktur:** Spieler-Karte als `StatelessWidget`, Daten via Parameter.
*   **UI-Feedback:** Nutze abgerundete Ecken (`BorderRadius.circular(16)`), dezente Schatten (`BoxShadow`) und Grid-Layouts.
*   **Daten-Flow:** Cloud Function -> Firestore Collection (`ladder_data`) -> Flutter StreamBuilder.

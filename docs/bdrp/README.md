# BDRP – Business Disaster Recovery Plan

[← Terug naar README](../../README.md)

Het herstelplan voor de beheerder van het BreachOut-platform op Cluster1. Het volledige plan staat in het Word-document [BDRP_BreachOut_Cluster1.docx](BDRP_BreachOut_Cluster1.docx).

## Overzicht

| Onderdeel | Waarde |
| --- | --- |
| Document | [BDRP_BreachOut_Cluster1.docx](BDRP_BreachOut_Cluster1.docx) |
| Versie | 0.1 (9 oktober 2026) |
| Voor wie | De beheerder van de omgeving en het projectteam van NextLine |
| Opdrachtgever | IronHold Labs |
| Opgesteld door | Jafeth Worm, Marlie van Leersum, Youri Bochoven |
| Koppeling met FO/TO | FR13 en US20 (continuïteitsplan / BCDR-plan), TO hoofdstuk 7 (beheerprocedures) |

## Waarvoor is het

Het BDRP vertelt de beheerder wat hij moet doen als een deel van de omgeving uitvalt. Het beantwoordt drie vragen:

1. Valt er iets uit, wat moet je dan doen?
2. Wat is er gebouwd om de omgeving weer werkend te krijgen?
3. Wat heeft NextLine gedaan om dat mogelijk te maken?

Gebruik het plan:

- bij een alertmail of een storing;
- bij het afsluiten en opstarten van het cluster rond de les (scenario 7.3);
- bij het testen van failover, back-up en meldingen (T-01, T-04 en T-06);
- als onderbouwing voor docent, opdrachtgever en investeerder dat herstel binnen 1 uur (NFR1) geregeld is.

## Voor wie is het

| Wie | Gebruikt het voor |
| --- | --- |
| Beheerder | Storingen oplossen met de stappen per scenario |
| Projectteam NextLine | Het plan bijwerken na wijzigingen en de tests uitvoeren |
| Docent en opdrachtgever (IronHold Labs) | Beoordelen of continuïteit en herstel geregeld zijn |

## Wat staat erin

| Hoofdstuk | Inhoud |
| --- | --- |
| 1. Inleiding | Doel, hoe je het plan gebruikt, scope en bronnen |
| 2. Hersteldoelen en uitgangspunten | Herstel binnen 1 uur, 99,5% beschikbaarheid, maximaal één lesdag dataverlies en de herstelvolgorde |
| 3. Overzicht van de omgeving | Nodes, containers, Ceph, VLAN's, externe diensten en waar de geheimen staan (zonder de waarden) |
| 4. Wat is er gebouwd | HA, Ceph-replicatie, load balancing, back-up naar de PBS, monitoring en documentatie; wat automatisch gebeurt en wat niet |
| 5. Wat heeft NextLine gedaan | Tijdlijn van de werkzaamheden en de stand van de tests |
| 6. Eerste reactie bij een storing | Stappenplan, uitleg bij de controles en de tabel symptoom → scenario |
| 7. Herstelscenario's | 14 scenario's met stappen, van uitval van één node tot een gelekt wachtwoord |
| 8. Testen en onderhouden | Vaste controles en tests, en wanneer het plan wordt bijgewerkt |
| 9. Restrisico's en verbeterpunten | Bekende risico's met advies en prioriteit |
| Bijlagen A t/m D | Commandokaart, adressen, incidentformulier en koppeling met FO en TO |

## Bij een storing

1. Lees de melding en noteer het tijdstip.
2. Open Grafana op `http://192.168.10.20:3000` en bekijk het dashboard **Cluster1 – Overzicht**.
3. Voer in de Shell van een werkende node uit:

```
pvecm status
ha-manager status
ceph -s
```

4. Zoek in de tabel hieronder het scenario dat past en volg de stappen in hoofdstuk 7 van het document.
5. Leg het incident vast met het formulier in bijlage C.

## Welk scenario

| Wat zie je | Scenario |
| --- | --- |
| Mail KRITIEK – Node offline, één node rood in de webinterface | 7.1 Eén node valt uit |
| Meerdere nodes rood, Quorate: No, alles staat stil | 7.2 Twee of drie nodes vallen uit |
| Begin of einde van de les, of na een stroomuitval | 7.3 Cluster afsluiten en opstarten |
| Mail Ceph-health, `ceph -s` meldt een OSD down | 7.4 Ceph-schijf (OSD) defect |
| Mail Ceph-opslag (70% of 80%) of HEALTH_ERR | 7.5 Ceph-opslag bijna vol of HEALTH_ERR |
| Een node start niet meer op | 7.6 Node opnieuw installeren |
| Een container start niet, de configuratie is kapot of data is weg | 7.7 Container herstellen uit de back-up |
| cc3-test, docker01 of web01 weg na uitval van pve001 | 7.8 Containers op local-lvm terugzetten |
| Mail CPU of geheugen node boven 80% of 90% | 7.9 Node overbelast |
| Geen meldingen, Grafana of Prometheus werkt niet | 7.10 Monitoring of meldingen werken niet |
| challenges.ms-dev.nl onbereikbaar of certificaatfout | 7.11 Website onbereikbaar |
| Niets bereikbaar vanaf WiFi NextLine, nodes hebben geen internet | 7.12 FortiGate of FortiSwitch uitgevallen |
| Back-uptaak mislukt, pbs-nextline staat niet op active | 7.13 Back-upserver (PBS) niet bereikbaar |
| Een wachtwoord of token is gelekt of kwijt | 7.14 Wachtwoord of token gelekt of kwijt |

## Het plan bijwerken

Werk het plan bij na elk incident, na elke wijziging aan het cluster, het netwerk of de containers, en na een geslaagde test.

1. Open het Word-document en voer de wijziging door.
2. Verhoog het versienummer op het voorblad en in het versiebeheer.
3. Pas de regel **Versie** in deze pagina aan.
4. Ga in GitHub naar de map `docs/bdrp`, klik op **Add file > Upload files** en upload het document met dezelfde bestandsnaam.

## Let op

- Download het document ook naar je laptop of print het. Valt de FortiGate of het internet uit, dan kom je niet bij GitHub.
- GitHub toont een Word-bestand niet in de browser. Klik op het bestand en daarna op **Download raw file**.
- Zet nooit wachtwoorden of tokens in het BDRP. Het plan zegt alleen waar ze staan.
- Houd de bestandsnaam gelijk, dan blijven de links werken. Oude versies blijven bewaard in de geschiedenis van GitHub.

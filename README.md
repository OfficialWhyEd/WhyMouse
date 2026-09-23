# MisuraMouse

**Measure the real DPI and polling rate of a mouse from PowerShell, no extra software.**

Nato per una domanda semplice: la sensibilità consigliata da un calcolatore non tornava. Invece di fidarsi
del numero scritto sulla scatola, si misura.

| File | Cosa fa |
|---|---|
| `misura-dpi.ps1` | trascini il mouse per una distanza nota, conta i conteggi grezzi e calcola il DPI vero |
| `confronta-mouse.ps1` | legge il descrittore USB: velocità del bus e tetto fisico di polling |
| `MISURA DPI.cmd` | avvio con un clic |

Risultato del primo uso: il mouse era un dispositivo USB *low-speed*, con un tetto fisico di 125 Hz.
Nessun software poteva cambiarlo. Una misura di 5 minuti ha evitato settimane di impostazioni inutili.

---

Parte di **[WhyEcosystem 2023-2026](https://github.com/OfficialWhyEd/WhyEcosystem-2023-2026)**: il percorso di WhyEd, producer e sound engineer che costruisce sistemi AI dirigendo gli agenti.  
Costruito da WhyEd con Claude Code

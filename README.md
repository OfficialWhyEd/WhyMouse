# WhyMouse

**Measure the real DPI and polling rate of a mouse from PowerShell, no extra software.**

`PowerShell` · `C# inline (WinForms)` · stato: **funzionante**

Due piccoli strumenti che misurano il mouse davvero, invece di fidarsi del numero scritto sulla scatola.

## Cosa fa
- **DPI vero**: sullo schermo compare un righello in centimetri; trascini il mouse per quella distanza e il
  programma conta i movimenti grezzi e calcola il DPI;
- **reattività**: misura quanti aggiornamenti al secondo arrivano davvero (Hz), il tremolio fra un pacchetto e
  l'altro e i buchi;
- **confronto fra due mouse**: collegati insieme, dà un punteggio a ognuno e dice quale conviene e perché.

## Come funziona
```
Raw Input di Windows ─► conteggi grezzi del sensore ─► DPI = conteggi / pollici percorsi
                     └► tempi fra i pacchetti      ─► Hz, tremolio, buchi ─► punteggio
```
Niente driver e niente programmi da installare: il codice C# è dentro gli script e PowerShell lo compila al volo.

## Struttura
| File | Cosa fa |
|---|---|
| `misura-dpi.ps1` | righello a schermo e misura del DPI |
| `confronta-mouse.ps1` | reattività, tremolio e confronto fra due mouse |
| `MISURA DPI.cmd` | avvio con un doppio clic |

## Come si avvia
Doppio clic su `MISURA DPI.cmd`, oppure:
```
powershell -ExecutionPolicy Bypass -File misura-dpi.ps1
powershell -ExecutionPolicy Bypass -File confronta-mouse.ps1
```

## Stato
Funziona. Il primo uso ha dato una risposta netta: il mouse era un dispositivo USB *low-speed*, con un tetto
fisico di 125 Hz. Nessun software poteva cambiarlo: serviva un altro mouse.

## Perché è nato
La sensibilità nel gioco e quella suggerita da un calcolatore online non tornavano. Invece di provare
impostazioni a caso per settimane, si è misurato in cinque minuti.

---

Parte di **[WhyEcosystem 2023-2026](https://github.com/OfficialWhyEd/WhyEcosystem-2023-2026)**: il percorso di WhyEd, producer e sound engineer che costruisce sistemi AI dirigendo gli agenti.  
Costruito da WhyEd con Claude Code

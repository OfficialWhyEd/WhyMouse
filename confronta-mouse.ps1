Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$src = @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Drawing;

public class Topo {
    public string Etichetta = "?";
    public long Pacchetti = 0;
    public double TempoMov = 0;      // secondi di movimento vero
    public double SommaInt = 0;      // somma degli intervalli in ms
    public double SommaInt2 = 0;     // somma dei quadrati, per il tremolio
    public long NInt = 0;
    public long MaxDx = 0;
    public long Vuoti = 0;           // pacchetti arrivati senza movimento: buchi del sensore
    public double UltimoMs = -1;
    public bool Finito = false;

    public double Hz { get { return TempoMov > 0.2 ? Pacchetti / TempoMov : 0; } }
    public double IntMedio { get { return NInt > 0 ? SommaInt / NInt : 0; } }
    public double Tremolio {
        get {
            if (NInt < 10) return 0;
            double m = SommaInt / NInt;
            double v = (SommaInt2 / NInt) - (m * m);
            return v > 0 ? Math.Sqrt(v) : 0;
        }
    }
    public double Buchi { get { return Pacchetti > 0 ? Vuoti * 100.0 / (Pacchetti + Vuoti) : 0; } }
}

public class ConfrontoForm : Form {

    [StructLayout(LayoutKind.Sequential)]
    public struct RAWINPUTDEVICE { public ushort usUsagePage; public ushort usUsage; public uint dwFlags; public IntPtr hwndTarget; }
    [StructLayout(LayoutKind.Sequential)]
    public struct RAWINPUTHEADER { public uint dwType; public uint dwSize; public IntPtr hDevice; public IntPtr wParam; }

    [DllImport("user32.dll", SetLastError=true)]
    static extern bool RegisterRawInputDevices([In] RAWINPUTDEVICE[] d, uint num, uint size);
    [DllImport("user32.dll")]
    static extern uint GetRawInputData(IntPtr h, uint cmd, IntPtr data, ref uint size, uint hdrSize);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    static extern uint GetRawInputDeviceInfoW(IntPtr hDevice, uint cmd, IntPtr data, ref uint size);

    const int WM_INPUT = 0x00FF;
    const uint RID_INPUT = 0x10000003;
    const uint RIDEV_INPUTSINK = 0x00000100;
    const uint RIDI_DEVICENAME = 0x20000007;
    const double SECONDI_RICHIESTI = 8.0;

    System.Diagnostics.Stopwatch cron = new System.Diagnostics.Stopwatch();
    Dictionary<long, Topo> topi = new Dictionary<long, Topo>();
    Timer battito;
    public string FileMisure = "";

    FlowLayoutPanel flow;
    Label lTitolo, lIstr, lStato, lA, lB, lVerdetto, lPie;
    List<Label> tutte = new List<Label>();

    static Color SFONDO = Color.FromArgb(16,16,20);
    static Color VERDE  = Color.FromArgb(110,225,140);
    static Color GIALLO = Color.FromArgb(255,205,110);
    static Color GRIGIO = Color.FromArgb(170,170,185);

    public ConfrontoForm() {
        this.Text = "Quale mouse e meglio";
        this.BackColor = SFONDO;
        this.ForeColor = Color.White;
        this.StartPosition = FormStartPosition.CenterScreen;
        this.Size = new Size(1150, 900);
        this.MinimumSize = new Size(800, 600);
        this.KeyPreview = true;
        this.AutoScaleMode = AutoScaleMode.None;

        flow = new FlowLayoutPanel();
        flow.Dock = DockStyle.Fill;
        flow.FlowDirection = FlowDirection.TopDown;
        flow.WrapContents = false;
        flow.AutoScroll = true;
        flow.BackColor = SFONDO;
        flow.Padding = new Padding(40, 26, 40, 26);
        this.Controls.Add(flow);

        lTitolo = Nuova("QUALE MOUSE E MEGLIO", 25, FontStyle.Bold, Color.White, 14);
        lIstr = Nuova(
            "Non devi misurare niente. Non devi premere niente.\r\n" +
            "\r\n" +
            "1.  Muovi UN mouse come se stessi giocando: scatti, giri, mira. Per 8 secondi\r\n" +
            "2.  Poi lascialo e fai la stessa cosa con l altro\r\n" +
            "3.  Il verdetto esce da solo",
            15, FontStyle.Regular, GRIGIO, 22);

        lStato = Nuova("In attesa. Muovi un mouse.", 19, FontStyle.Bold, GIALLO, 18);
        lA = Nuova("", 15, FontStyle.Regular, Color.White, 14);
        lB = Nuova("", 15, FontStyle.Regular, Color.White, 20);
        lVerdetto = Nuova("", 22, FontStyle.Bold, VERDE, 16);
        lPie = Nuova("R = ricomincia da capo     ESC = chiudi", 11, FontStyle.Regular, Color.FromArgb(125,125,140), 4);

        this.KeyDown += new KeyEventHandler(Tasto);
        this.Resize += new EventHandler(Ridimensiona);
        this.Shown += new EventHandler(Ridimensiona);

        cron.Start();
        battito = new Timer();
        battito.Interval = 150;
        battito.Tick += new EventHandler(Battito);
        battito.Start();
    }

    Label Nuova(string testo, float dim, FontStyle stile, Color col, int sotto) {
        Label l = new Label();
        l.Text = testo;
        l.Font = new Font("Segoe UI", dim, stile);
        l.ForeColor = col;
        l.AutoSize = true;
        l.Margin = new Padding(0, 0, 0, sotto);
        flow.Controls.Add(l);
        tutte.Add(l);
        return l;
    }

    void Ridimensiona(object s, EventArgs e) {
        int larg = flow.ClientSize.Width - flow.Padding.Left - flow.Padding.Right - 24;
        if (larg < 300) larg = 300;
        foreach (Label l in tutte) l.MaximumSize = new Size(larg, 0);
    }

    protected override void OnHandleCreated(EventArgs e) {
        base.OnHandleCreated(e);
        RAWINPUTDEVICE[] rid = new RAWINPUTDEVICE[1];
        rid[0].usUsagePage = 0x01; rid[0].usUsage = 0x02;
        rid[0].dwFlags = RIDEV_INPUTSINK; rid[0].hwndTarget = this.Handle;
        RegisterRawInputDevices(rid, 1, (uint)Marshal.SizeOf(typeof(RAWINPUTDEVICE)));
    }

    string LeggiNome(IntPtr h) {
        uint size = 0;
        GetRawInputDeviceInfoW(h, RIDI_DEVICENAME, IntPtr.Zero, ref size);
        if (size == 0 || size > 4000) return "sconosciuto";
        IntPtr p = Marshal.AllocHGlobal((int)((size + 1) * 2));
        try {
            GetRawInputDeviceInfoW(h, RIDI_DEVICENAME, p, ref size);
            string s = Marshal.PtrToStringUni(p);
            if (s == null) return "sconosciuto";
            int i = s.IndexOf("VID_");
            if (i >= 0) {
                string t = s.Substring(i);
                int j = t.IndexOf('#');
                if (j > 0) t = t.Substring(0, j);
                return t.Replace("&", " ");
            }
            return s;
        } finally { Marshal.FreeHGlobal(p); }
    }

    Topo Trova(IntPtr h) {
        long k = h.ToInt64();
        if (topi.ContainsKey(k)) return topi[k];
        Topo t = new Topo();
        t.Etichetta = LeggiNome(h);
        topi[k] = t;
        return t;
    }

    protected override void WndProc(ref Message m) {
        if (m.Msg == WM_INPUT) {
            uint size = 0;
            uint hdr = (uint)Marshal.SizeOf(typeof(RAWINPUTHEADER));
            GetRawInputData(m.LParam, RID_INPUT, IntPtr.Zero, ref size, hdr);
            if (size > 0) {
                IntPtr buf = Marshal.AllocHGlobal((int)size);
                try {
                    if (GetRawInputData(m.LParam, RID_INPUT, buf, ref size, hdr) == size) {
                        if (Marshal.ReadInt32(buf, 0) == 0) {
                            IntPtr hDev = Marshal.ReadIntPtr(buf, 8);
                            int off = (int)hdr;
                            short flags = Marshal.ReadInt16(buf, off);
                            int dx = Marshal.ReadInt32(buf, off + 12);
                            int dy = Marshal.ReadInt32(buf, off + 16);
                            if ((flags & 1) == 0) {
                                Topo t = Trova(hDev);
                                if (!t.Finito) {
                                    double ora = cron.Elapsed.TotalMilliseconds;
                                    if (dx == 0 && dy == 0) {
                                        t.Vuoti++;
                                    } else {
                                        t.Pacchetti++;
                                        if (Math.Abs(dx) > t.MaxDx) t.MaxDx = Math.Abs(dx);
                                        if (t.UltimoMs >= 0) {
                                            double dt = ora - t.UltimoMs;
                                            // sopra i 40 ms vuol dire che si era fermato: non conta
                                            if (dt > 0 && dt < 40) {
                                                t.TempoMov += dt / 1000.0;
                                                t.SommaInt += dt;
                                                t.SommaInt2 += dt * dt;
                                                t.NInt++;
                                            }
                                        }
                                    }
                                    t.UltimoMs = ora;
                                }
                            }
                        }
                    }
                } finally { Marshal.FreeHGlobal(buf); }
            }
        }
        base.WndProc(ref m);
    }

    void Tasto(object s, KeyEventArgs e) {
        if (e.KeyCode == Keys.Escape) { this.Close(); return; }
        if (e.KeyCode == Keys.R) { topi.Clear(); Aggiorna(); return; }
    }

    void Battito(object s, EventArgs e) {
        foreach (Topo t in topi.Values) {
            if (!t.Finito && t.TempoMov >= SECONDI_RICHIESTI) {
                t.Finito = true;
                Registra(t);
            }
        }
        Aggiorna();
    }

    void Registra(Topo t) {
        string riga = string.Format("{0}   {1}   {2:F0} Hz   tremolio {3:F2} ms   buchi {4:F1}%   maxDx {5}   {6:F1} s",
            DateTime.Now.ToString("HH:mm:ss"), t.Etichetta, t.Hz, t.Tremolio, t.Buchi, t.MaxDx, t.TempoMov);
        try { if (FileMisure != "") System.IO.File.AppendAllText(FileMisure, riga + Environment.NewLine, Encoding.UTF8); } catch {}
    }

    static string Voto(Topo t) {
        double p = 0;
        if (t.Hz >= 900) p += 4; else if (t.Hz >= 450) p += 3; else if (t.Hz >= 230) p += 2; else p += 1;
        if (t.Tremolio <= 0.6) p += 3; else if (t.Tremolio <= 1.5) p += 2; else if (t.Tremolio <= 3.0) p += 1;
        if (t.Buchi <= 1) p += 2; else if (t.Buchi <= 5) p += 1;
        if (p >= 8) return "OTTIMO";
        if (p >= 6) return "BUONO";
        if (p >= 4) return "SUFFICIENTE";
        return "SCARSO";
    }

    static double Punti(Topo t) {
        double p = 0;
        if (t.Hz >= 900) p += 4; else if (t.Hz >= 450) p += 3; else if (t.Hz >= 230) p += 2; else p += 1;
        if (t.Tremolio <= 0.6) p += 3; else if (t.Tremolio <= 1.5) p += 2; else if (t.Tremolio <= 3.0) p += 1;
        if (t.Buchi <= 1) p += 2; else if (t.Buchi <= 5) p += 1;
        return p;
    }

    string Scheda(Topo t, string nome) {
        StringBuilder sb = new StringBuilder();
        sb.AppendLine(nome + "   -   " + t.Etichetta);
        if (!t.Finito) {
            int perc = (int)(t.TempoMov * 100 / SECONDI_RICHIESTI);
            if (perc > 99) perc = 99;
            int barre = perc / 5;
            string barra = "";
            for (int i = 0; i < 20; i++) barra += (i < barre ? "#" : ".");
            sb.AppendLine("   " + barra + "   " + perc + "%   continua a muoverlo");
        } else {
            sb.AppendLine("   Reattivita:        " + t.Hz.ToString("F0") + " aggiornamenti al secondo");
            sb.AppendLine("   Regolarita:        " + t.Tremolio.ToString("F2").Replace(".", ",") + " ms di tremolio  (piu e basso, piu la mira e stabile)");
            sb.AppendLine("   Buchi del sensore: " + t.Buchi.ToString("F1").Replace(".", ",") + " %");
            sb.AppendLine("   GIUDIZIO:          " + Voto(t));
        }
        return sb.ToString();
    }

    void Aggiorna() {
        List<Topo> lista = new List<Topo>(topi.Values);

        if (lista.Count == 0) {
            lStato.Text = "In attesa. Muovi un mouse.";
            lStato.ForeColor = GIALLO;
            lA.Text = ""; lB.Text = ""; lVerdetto.Text = "";
            return;
        }

        int finiti = 0;
        foreach (Topo t in lista) if (t.Finito) finiti++;

        if (finiti == lista.Count && lista.Count >= 2) {
            lStato.Text = "FATTO. Ecco il confronto.";
            lStato.ForeColor = VERDE;
        } else if (lista.Count == 1 && finiti == 1) {
            lStato.Text = "Primo mouse finito. ORA MUOVI L ALTRO.";
            lStato.ForeColor = GIALLO;
        } else {
            lStato.Text = "Sto misurando. Muovi come se giocassi.";
            lStato.ForeColor = GIALLO;
        }

        lA.Text = Scheda(lista[0], "MOUSE 1");
        lB.Text = lista.Count > 1 ? Scheda(lista[1], "MOUSE 2") : "MOUSE 2   -   non ancora mosso";

        if (lista.Count >= 2 && finiti >= 2) {
            Topo a = lista[0], b = lista[1];
            double pa = Punti(a), pb = Punti(b);
            Topo vince = pa >= pb ? a : b;
            Topo perde = pa >= pb ? b : a;
            string nomeV = pa >= pb ? "MOUSE 1" : "MOUSE 2";
            StringBuilder sb = new StringBuilder();
            if (Math.Abs(pa - pb) < 1) {
                sb.AppendLine("PARI. Si equivalgono: tieni quello che ti sta meglio in mano.");
            } else {
                sb.AppendLine("TIENI IL " + nomeV + "   (" + vince.Etichetta + ")");
                string perche = "";
                if (vince.Hz > perde.Hz * 1.2) perche = "e piu reattivo: " + vince.Hz.ToString("F0") + " contro " + perde.Hz.ToString("F0") + " al secondo";
                else if (vince.Tremolio < perde.Tremolio * 0.7) perche = "ha la mano piu ferma: " + vince.Tremolio.ToString("F2").Replace(".", ",") + " contro " + perde.Tremolio.ToString("F2").Replace(".", ",") + " ms di tremolio";
                else perche = "perde meno colpi del sensore";
                sb.AppendLine("Perche " + perche);
            }
            lVerdetto.Text = sb.ToString();
        } else {
            lVerdetto.Text = "";
        }
    }
}
"@

Add-Type -TypeDefinition $src -ReferencedAssemblies System.Windows.Forms, System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()
$f = New-Object ConfrontoForm
$f.FileMisure = Join-Path $PSScriptRoot "confronto.txt"
[System.Windows.Forms.Application]::Run($f)

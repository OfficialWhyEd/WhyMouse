Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$src = @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Drawing;
using System.Drawing.Drawing2D;

public class Righello : Panel {
    public double PxPerCm = 37.8;
    public int Cm = 20;
    public Righello() {
        this.DoubleBuffered = true;
        this.BackColor = Color.FromArgb(28,28,34);
    }
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        Pen p = new Pen(Color.White, 2f);
        Pen pm = new Pen(Color.FromArgb(150,150,165), 1.5f);
        Font f = new Font("Segoe UI", 10F, FontStyle.Bold);
        Brush b = new SolidBrush(Color.White);
        int baseY = this.Height - 6;
        g.DrawLine(p, 8, baseY, (float)(8 + Cm * PxPerCm), baseY);
        for (int i = 0; i <= Cm; i++) {
            float x = (float)(8 + i * PxPerCm);
            bool grossa = (i % 5 == 0);
            g.DrawLine(grossa ? p : pm, x, baseY, x, baseY - (grossa ? 30 : 15));
            if (grossa) g.DrawString(i.ToString(), f, b, x - 6, baseY - 52);
        }
        for (int i = 0; i < Cm; i++) {
            float x = (float)(8 + (i + 0.5) * PxPerCm);
            g.DrawLine(pm, x, baseY, x, baseY - 9);
        }
        p.Dispose(); pm.Dispose(); f.Dispose(); b.Dispose();
    }
}

public class Topo {
    public IntPtr H;
    public string Etichetta = "?";
    public long X, Y, Pacchetti, MaxDx, XTot;
}

public class DpiForm : Form {

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

    bool running = false;
    bool modoPrecisione = false;
    volatile bool assoluto = false;
    bool avvisatoAssoluto = false;
    Timer battito;
    int tickN = 0;
    long pxCursore = 0;
    Point centro = Point.Empty;
    double distanza = 29.7;
    string nomeDist = "foglio A4 per il lungo";
    System.Diagnostics.Stopwatch cron = new System.Diagnostics.Stopwatch();
    List<string> storico = new List<string>();
    Dictionary<long, Topo> topi = new Dictionary<long, Topo>();
    public string FileMisure = "";
    public double PxPerCm = 37.8;

    FlowLayoutPanel flow;
    Label lTitolo, lQuanto, lPassi, lRigTesto, lStato, lNumero, lRis, lStorico, lPie;
    Righello rig;
    List<Label> tutte = new List<Label>();

    static Color SFONDO = Color.FromArgb(16,16,20);
    static Color VERDE  = Color.FromArgb(110,225,140);
    static Color GIALLO = Color.FromArgb(255,205,110);
    static Color ROSSO  = Color.FromArgb(255,130,130);

    public DpiForm() {
        this.Text = "Misura DPI del mouse";
        this.BackColor = SFONDO;
        this.ForeColor = Color.White;
        this.StartPosition = FormStartPosition.CenterScreen;
        this.Size = new Size(1200, 980);
        this.MinimumSize = new Size(820, 640);
        this.KeyPreview = true;
        this.AutoScaleMode = AutoScaleMode.None;

        flow = new FlowLayoutPanel();
        flow.Dock = DockStyle.Fill;
        flow.FlowDirection = FlowDirection.TopDown;
        flow.WrapContents = false;
        flow.AutoScroll = true;
        flow.BackColor = SFONDO;
        flow.Padding = new Padding(38, 20, 38, 20);
        this.Controls.Add(flow);

        lTitolo  = Nuova("MISURA DPI  -  DUE MOUSE INSIEME", 22, FontStyle.Bold, Color.White, 10);
        lQuanto  = Nuova("", 19, FontStyle.Bold, Color.FromArgb(140,200,255), 8);
        lPassi   = Nuova("", 13, FontStyle.Regular, Color.FromArgb(180,180,195), 14);

        lRigTesto = Nuova("RIGHELLO VERO", 10, FontStyle.Bold, Color.FromArgb(140,140,155), 4);
        rig = new Righello();
        rig.Size = new Size(800, 68);
        rig.Margin = new Padding(0, 0, 0, 14);
        flow.Controls.Add(rig);

        lStato   = Nuova("", 17, FontStyle.Bold, VERDE, 8);
        lNumero  = Nuova("", 26, FontStyle.Bold, Color.White, 12);
        lRis     = Nuova("", 13, FontStyle.Regular, Color.FromArgb(232,232,242), 14);
        lStorico = Nuova("", 11, FontStyle.Regular, Color.FromArgb(150,200,255), 12);
        lPie     = Nuova("SPAZIO avvia e ferma     P prova di precisione     1 2 3 4 distanza     R pulisci     ESC chiudi",
                         10, FontStyle.Regular, Color.FromArgb(125,125,140), 4);

        this.KeyDown += new KeyEventHandler(Tasto);
        this.Resize += new EventHandler(Ridimensiona);
        this.Shown += new EventHandler(Ridimensiona);

        battito = new Timer();
        battito.Interval = 15;
        battito.Tick += new EventHandler(Battito);
        battito.Start();

        Aggiorna();
    }

    public void ImpostaRighello(double pxcm) {
        PxPerCm = pxcm; rig.PxPerCm = pxcm; rig.Cm = 20;
        rig.Width = (int)(20 * pxcm) + 20; rig.Invalidate();
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
        t.H = h;
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
                            // niente grafica qui dentro: se rallento, Windows butta i pacchetti
                            if ((flags & 1) != 0) {
                                assoluto = true;
                            } else if (running) {
                                Topo t = Trova(hDev);
                                t.X += dx; t.Y += dy; t.XTot += Math.Abs(dx);
                                if (dx != 0 || dy != 0) t.Pacchetti++;
                                if (Math.Abs(dx) > t.MaxDx) t.MaxDx = Math.Abs(dx);
                            }
                        }
                    }
                } finally { Marshal.FreeHGlobal(buf); }
            }
        }
        base.WndProc(ref m);
    }

    void Battito(object s, EventArgs e) {
        if (running) {
            Point p = Cursor.Position;
            pxCursore += Math.Abs(p.X - centro.X);
            if (p != centro) Cursor.Position = centro;
        }
        tickN++;
        if (assoluto && !avvisatoAssoluto) { avvisatoAssoluto = true; Aggiorna(); return; }
        if (!running) return;
        if (tickN % 5 != 0) return;
        lNumero.Text = RigaViva();
    }

    string RigaViva() {
        StringBuilder sb = new StringBuilder();
        bool primo = true;
        foreach (Topo t in topi.Values) {
            if (!primo) sb.Append("\r\n");
            primo = false;
            sb.Append(t.Etichetta + " :  " + Math.Abs(t.X) + " conteggi");
        }
        if (primo) sb.Append("muovi un mouse...");
        return sb.ToString();
    }

    void Preset(double cm, string nome) {
        if (running) return;
        distanza = cm; nomeDist = nome; Aggiorna();
    }

    void Tasto(object s, KeyEventArgs e) {
        if (e.KeyCode == Keys.Escape) { this.Close(); return; }
        if (e.KeyCode == Keys.R) { storico.Clear(); topi.Clear(); running = false; Aggiorna(); return; }
        if (e.KeyCode == Keys.P) { if (!running) { modoPrecisione = !modoPrecisione; topi.Clear(); } Aggiorna(); return; }
        if (e.KeyCode == Keys.D1 || e.KeyCode == Keys.NumPad1) { Preset(29.7, "foglio A4 per il lungo"); return; }
        if (e.KeyCode == Keys.D2 || e.KeyCode == Keys.NumPad2) { Preset(21.0, "foglio A4 per il largo"); return; }
        if (e.KeyCode == Keys.D3 || e.KeyCode == Keys.NumPad3) { Preset(20.0, "20 cm col righello qui sopra"); return; }
        if (e.KeyCode == Keys.D4 || e.KeyCode == Keys.NumPad4) { Preset(10.0, "10 cm col righello qui sopra"); return; }
        if (e.KeyCode == Keys.Up)   { if (!running && distanza < 60) { distanza += 1; nomeDist = "misura tua"; } Aggiorna(); return; }
        if (e.KeyCode == Keys.Down) { if (!running && distanza > 2)  { distanza -= 1; nomeDist = "misura tua"; } Aggiorna(); return; }
        if (e.KeyCode == Keys.Space) {
            if (!running) {
                topi.Clear(); assoluto = false; avvisatoAssoluto = false; pxCursore = 0;
                Rectangle sc = Screen.PrimaryScreen.Bounds;
                centro = new Point(sc.Width / 2, sc.Height / 2);
                Cursor.Position = centro;
                running = true; cron.Reset(); cron.Start();
            } else {
                running = false; cron.Stop();
                Salva();
            }
            Aggiorna();
        }
    }

    static int StageVicino(double dpi) {
        int[] tipici = new int[] {200,400,600,800,1000,1200,1600,2000,2400,3200,4000,4800,6400,8000,12000,16000,20000,26000};
        int best = tipici[0]; double diff = double.MaxValue;
        foreach (int t in tipici) { double d = Math.Abs(t - dpi); if (d < diff) { diff = d; best = t; } }
        return best;
    }

    void Salva() {
        double sec = cron.Elapsed.TotalSeconds;
        foreach (Topo t in topi.Values) {
            if (t.XTot < 100) continue;
            double dpi = Math.Abs((double)t.X) / (distanza / 2.54);
            double hz = sec > 0 ? t.Pacchetti / sec : 0;
            string riga;
            if (modoPrecisione) {
                double err = t.XTot > 0 ? Math.Abs((double)t.X) * 100.0 / t.XTot : 0;
                riga = string.Format("{0}   {1}   PRECISIONE   percorso {2}   residuo {3}   errore {4:F1}%   {5:F0} Hz   maxDx {6}   {7:F1} s",
                    DateTime.Now.ToString("HH:mm:ss"), t.Etichetta, t.XTot, Math.Abs(t.X), err, hz, t.MaxDx, sec);
            } else {
                riga = string.Format("{0}   {1}   {2:F1} cm   {3} conteggi   {4:F0} DPI   (stage {5})   {6:F0} Hz   maxDx {7}   {8:F1} s",
                    DateTime.Now.ToString("HH:mm:ss"), t.Etichetta, distanza, Math.Abs(t.X), dpi, StageVicino(dpi), hz, t.MaxDx, sec);
            }
            storico.Insert(0, riga);
            try { if (FileMisure != "") System.IO.File.AppendAllText(FileMisure, riga + Environment.NewLine, Encoding.UTF8); } catch {}
        }
    }

    void Aggiorna() {
        if (!modoPrecisione) lQuanto.Text = "DEVI PERCORRERE:   " + distanza.ToString("F1").Replace(".", ",") + " cm      (" + nomeDist + ")";

        if (modoPrecisione) {
            lQuanto.Text = "PROVA DI PRECISIONE   (niente righello, niente centimetri)";
            lPassi.Text =
                "Dice se il sensore e affidabile. E il difetto che rovina la mira.\r\n" +
                "\r\n" +
                "1.  Metti il mouse in un punto e RICORDATELO (un segno sul tappetino)\r\n" +
                "2.  SPAZIO\r\n" +
                "3.  Avanti e indietro 5 volte, largo, poi RIMETTILO nel punto di partenza\r\n" +
                "4.  SPAZIO.   Se il mouse e buono torna quasi a zero";
        } else {
        lPassi.Text =
            "Muovi UN MOUSE PER VOLTA, sul tappetino. Il foglio va accanto, mai sotto.\r\n" +
            "\r\n" +
            "1.  Mouse allineato al bordo sinistro del foglio\r\n" +
            "2.  SPAZIO\r\n" +
            "3.  Trascina LENTO fino al bordo destro\r\n" +
            "4.  SPAZIO.   Durante la misura il cursore resta fermo al centro: e voluto";
        }

        if (assoluto) {
            lStato.Text = "ATTENZIONE: arrivano posizioni assolute. Cosi la misura non vale.";
            lStato.ForeColor = ROSSO;
        } else if (running) {
            lStato.Text = "STO MISURANDO...   arrivato in fondo premi SPAZIO";
            lStato.ForeColor = GIALLO;
        } else if (storico.Count > 0) {
            lStato.Text = "FERMO.   Ora prova con l altro mouse";
            lStato.ForeColor = VERDE;
        } else {
            lStato.Text = "PRONTO.   Premi SPAZIO per iniziare";
            lStato.ForeColor = VERDE;
        }

        lNumero.Text = RigaViva();

        if (!running && topi.Count > 0) {
            StringBuilder sb = new StringBuilder();
            double sec = cron.Elapsed.TotalSeconds;
            foreach (Topo t in topi.Values) {
                if (t.XTot < 100) continue;
                double hz = sec > 0 ? t.Pacchetti / sec : 0;
                sb.AppendLine(t.Etichetta);
                if (modoPrecisione) {
                    double err = t.XTot > 0 ? Math.Abs((double)t.X) * 100.0 / t.XTot : 0;
                    string giudizio;
                    if (err < 2)       giudizio = "OTTIMO, il sensore non perde niente";
                    else if (err < 6)  giudizio = "BUONO, va bene per giocare";
                    else if (err < 15) giudizio = "SCARSO, la mira balla";
                    else               giudizio = "DA BUTTARE per un FPS";
                    sb.AppendLine("   Percorso totale fatto:  " + t.XTot + " conteggi");
                    sb.AppendLine("   Non e tornato al punto di partenza per:  " + Math.Abs(t.X) + " conteggi");
                    sb.AppendLine("   ERRORE:  " + err.ToString("F1").Replace(".", ",") + " %   ->   " + giudizio);
                    sb.AppendLine("   " + hz.ToString("F0") + " pacchetti al secondo   |   salto massimo " + t.MaxDx + (t.MaxDx >= 126 ? "  SATURA" : ""));
                } else {
                    double dpi = Math.Abs((double)t.X) / (distanza / 2.54);
                    if (dpi < 150) {
                        sb.AppendLine("   MISURA DA BUTTARE: " + dpi.ToString("F0") + " DPI non esiste. Hai fatto meno strada di quella che hai detto, o il sensore perde.");
                    } else {
                        sb.AppendLine("   " + dpi.ToString("F0") + " DPI   ->  stage probabile " + StageVicino(dpi));
                        sb.AppendLine("   " + hz.ToString("F0") + " pacchetti al secondo   |   salto massimo " + t.MaxDx + (t.MaxDx >= 126 ? "  SATURA" : ""));
                        sb.AppendLine("   Valorant a 0,22:  " + (13062.857 / (0.22 * dpi)).ToString("F1").Replace(".", ",") + " cm per un giro");
                    }
                }
                sb.AppendLine("");
            }
            lRis.Text = sb.ToString();
        } else if (!running) {
            lRis.Text = "";
        }

        StringBuilder sb2 = new StringBuilder();
        if (storico.Count > 0) {
            sb2.AppendLine("MISURE FATTE");
            for (int i = 0; i < storico.Count && i < 8; i++) sb2.AppendLine(storico[i]);
        }
        lStorico.Text = sb2.ToString();
    }
}
"@

Add-Type -TypeDefinition $src -ReferencedAssemblies System.Windows.Forms, System.Drawing

$pxPerCm = 37.8
try {
    $mon = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams -ErrorAction Stop | Select-Object -First 1
    $largCm = [double]$mon.MaxHorizontalImageSize
    $largPx = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
    if ($largCm -gt 5 -and $largPx -gt 100) { $pxPerCm = $largPx / $largCm }
} catch { }

[System.Windows.Forms.Application]::EnableVisualStyles()
$f = New-Object DpiForm
$f.FileMisure = Join-Path $PSScriptRoot "misure2.txt"
$f.ImpostaRighello($pxPerCm)
[System.Windows.Forms.Application]::Run($f)

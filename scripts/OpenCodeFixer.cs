using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace OpenCodeFixerApp
{
    public class MainForm : Form
    {
        private Label lblTitle, lblSubtitle, lblIpHeader, lblIpValue, lblGuidHeader, lblGuidValue, lblStatus;
        private Panel cardIp;
        private Button btnRefreshIp, btnFixAll, btnCleanSessionsOnly, btnTestMiniMax, btnTestGlm;
        private TextBox txtLog;
        private ProgressBar progressBar;

        public MainForm()
        {
            InitializeComponent();
            RefreshInfoAsync();
        }

        private void InitializeComponent()
        {
            this.Text = "FIX AI - Rate Limit & Identity Fixer";
            this.Size = new Size(560, 710);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.FormBorderStyle = FormBorderStyle.FixedSingle;
            this.MaximizeBox = false;
            this.BackColor = Color.FromArgb(22, 24, 30);
            this.Font = new Font("Segoe UI", 9.5f, FontStyle.Regular);

            lblTitle = new Label { Text = " FIX AI", Location = new Point(20, 15), AutoSize = true, Font = new Font("Segoe UI", 16f, FontStyle.Bold), ForeColor = Color.FromArgb(235, 240, 255) };
            this.Controls.Add(lblTitle);

            lblSubtitle = new Label { Text = "1-Click Full Fix: Change IP + Reset Machine ID + Clean All Sessions", Location = new Point(22, 50), AutoSize = true, Font = new Font("Segoe UI", 9.5f), ForeColor = Color.FromArgb(145, 155, 175) };
            this.Controls.Add(lblSubtitle);

            cardIp = new Panel { Location = new Point(20, 80), Size = new Size(505, 90), BackColor = Color.FromArgb(30, 33, 44) };
            cardIp.Paint += (s, e) => { ControlPaint.DrawBorder(e.Graphics, cardIp.ClientRectangle, Color.FromArgb(48, 52, 68), ButtonBorderStyle.Solid); };

            lblIpHeader = new Label { Text = "CURRENT PUBLIC IP:", Location = new Point(16, 10), AutoSize = true, Font = new Font("Segoe UI", 8f, FontStyle.Bold), ForeColor = Color.FromArgb(120, 130, 155) };
            cardIp.Controls.Add(lblIpHeader);

            lblIpValue = new Label { Text = "Loading...", Location = new Point(16, 28), AutoSize = true, Font = new Font("Segoe UI", 13f, FontStyle.Bold), ForeColor = Color.FromArgb(80, 220, 160) };
            cardIp.Controls.Add(lblIpValue);

            lblGuidHeader = new Label { Text = "MACHINE GUID:", Location = new Point(16, 56), AutoSize = true, Font = new Font("Segoe UI", 7.5f, FontStyle.Bold), ForeColor = Color.FromArgb(120, 130, 155) };
            cardIp.Controls.Add(lblGuidHeader);

            lblGuidValue = new Label { Text = "Loading...", Location = new Point(110, 56), AutoSize = true, Font = new Font("Segoe UI", 7.5f), ForeColor = Color.FromArgb(180, 190, 210) };
            cardIp.Controls.Add(lblGuidValue);

            btnRefreshIp = new Button { Text = "Refresh", Location = new Point(400, 25), Size = new Size(88, 36), FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(45, 48, 64), ForeColor = Color.White, Cursor = Cursors.Hand };
            btnRefreshIp.FlatAppearance.BorderSize = 0;
            btnRefreshIp.Click += async (s, e) => await RefreshInfoAsync();
            cardIp.Controls.Add(btnRefreshIp);
            this.Controls.Add(cardIp);

            btnFixAll = new Button {
                Text = " 1-Click Fix All (New IP + New Machine ID + Clean Sessions)",
                Location = new Point(20, 185),
                Size = new Size(505, 52),
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(50, 100, 240),
                ForeColor = Color.White,
                Font = new Font("Segoe UI", 10.5f, FontStyle.Bold),
                Cursor = Cursors.Hand
            };
            btnFixAll.FlatAppearance.BorderSize = 0;
            btnFixAll.Click += async (s, e) => await RunFixAsync(true);
            this.Controls.Add(btnFixAll);

            btnCleanSessionsOnly = new Button {
                Text = " Clean & Reset Sessions Only (Keep Current IP)",
                Location = new Point(20, 247),
                Size = new Size(505, 40),
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(40, 44, 58),
                ForeColor = Color.FromArgb(200, 210, 230),
                Font = new Font("Segoe UI", 9.5f, FontStyle.Bold),
                Cursor = Cursors.Hand
            };
            btnCleanSessionsOnly.FlatAppearance.BorderSize = 0;
            btnCleanSessionsOnly.Click += async (s, e) => await RunFixAsync(false);
            this.Controls.Add(btnCleanSessionsOnly);

            btnTestMiniMax = new Button {
                Text = " Test MiniMax",
                Location = new Point(20, 297),
                Size = new Size(248, 38),
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(32, 36, 48),
                ForeColor = Color.FromArgb(180, 190, 210),
                Cursor = Cursors.Hand
            };
            btnTestMiniMax.FlatAppearance.BorderColor = Color.FromArgb(55, 60, 78);
            btnTestMiniMax.Click += async (s, e) => await TestModelAsync("MiniMax", "opencode/minimax-m3.1-flash-free");
            this.Controls.Add(btnTestMiniMax);

            btnTestGlm = new Button {
                Text = " Test GLM",
                Location = new Point(277, 297),
                Size = new Size(248, 38),
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(32, 36, 48),
                ForeColor = Color.FromArgb(180, 190, 210),
                Cursor = Cursors.Hand
            };
            btnTestGlm.FlatAppearance.BorderColor = Color.FromArgb(55, 60, 78);
            btnTestGlm.Click += async (s, e) => await TestModelAsync("GLM", "opencode/glm-5.3-flash-free");
            this.Controls.Add(btnTestGlm);

            progressBar = new ProgressBar { Location = new Point(20, 345), Size = new Size(505, 8), Style = ProgressBarStyle.Marquee, MarqueeAnimationSpeed = 0, Visible = false };
            this.Controls.Add(progressBar);

            lblStatus = new Label { Text = "Ready.", Location = new Point(20, 358), AutoSize = true, Font = new Font("Segoe UI", 8.5f), ForeColor = Color.FromArgb(140, 150, 170) };
            this.Controls.Add(lblStatus);

            txtLog = new TextBox {
                Location = new Point(20, 382),
                Size = new Size(505, 275),
                Multiline = true,
                ReadOnly = true,
                ScrollBars = ScrollBars.Vertical,
                BackColor = Color.FromArgb(15, 16, 20),
                ForeColor = Color.FromArgb(180, 220, 200),
                Font = new Font("Consolas", 8.5f),
                BorderStyle = BorderStyle.None
            };
            this.Controls.Add(txtLog);
        }

        private void Log(string msg)
        {
            if (this.InvokeRequired) { this.Invoke(new Action(() => Log(msg))); return; }
            txtLog.AppendText("[" + DateTime.Now.ToString("HH:mm:ss") + "] " + msg + "\r\n");
        }

        private void SetWorking(bool w, string s)
        {
            if (this.InvokeRequired) { this.Invoke(new Action(() => SetWorking(w, s))); return; }
            btnFixAll.Enabled = !w;
            btnCleanSessionsOnly.Enabled = !w;
            btnTestMiniMax.Enabled = !w;
            btnTestGlm.Enabled = !w;
            btnRefreshIp.Enabled = !w;
            progressBar.Visible = w;
            progressBar.MarqueeAnimationSpeed = w ? 30 : 0;
            lblStatus.Text = s;
        }

        private async Task RefreshInfoAsync()
        {
            lblIpValue.Text = "...";
            try {
                string ip = await Task.Run(() => {
                    using (var c = new WebClient()) {
                        c.Headers["User-Agent"] = "curl/7.88";
                        return c.DownloadString("https://api.ipify.org").Trim();
                    }
                });
                lblIpValue.Text = ip;
                Log("Public IP: " + ip);
            } catch { lblIpValue.Text = "Unknown"; }

            try {
                string guid = await Task.Run(() => {
                    return RunProcessOutput("cmd.exe", "/c reg query HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Cryptography /v MachineGuid");
                });
                if (guid.Contains("REG_SZ")) {
                    string[] parts = guid.Split(new string[] { "REG_SZ" }, StringSplitOptions.None);
                    if (parts.Length > 1) { lblGuidValue.Text = parts[1].Trim(); }
                }
            } catch { }
        }

        private async Task RunFixAsync(bool fullFix)
        {
            SetWorking(true, "Fixing in progress...");
            Log(fullFix ? "Starting 1-Click Full Fix (IP + Machine ID + Sessions)..." : "Cleaning sessions only...");
            await Task.Run(() => {
                try {
                    // 1. Kill OpenCode
                    foreach (var p in Process.GetProcessesByName("opencode")) { try { p.Kill(); } catch {} }

                    // 2. Change MachineGuid if fullFix
                    if (fullFix) {
                        string newGuid = Guid.NewGuid().ToString();
                        Log("Generating new Machine GUID: " + newGuid);
                        RunProcess("powershell.exe", "-NoProfile -ExecutionPolicy Bypass -Command \"Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Cryptography' -Name MachineGuid -Value '" + newGuid + "' -Force\"");
                    }

                    // 3. Clean cache & config files
                    string configDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".config", "opencode");
                    string sJson = Path.Combine(configDir, "service.json");
                    if (File.Exists(sJson)) { try { File.Delete(sJson); } catch {} }

                    string cacheDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), ".cache", "opencode");
                    if (Directory.Exists(cacheDir)) { try { Directory.Delete(cacheDir, true); } catch {} }

                    string tempDir = Path.GetTempPath();
                    try { foreach (var d in Directory.GetDirectories(tempDir, "opencode*")) { try { Directory.Delete(d, true); } catch {} } } catch {}

                    // 4. Run Python DB cleanup
                    string pyFile = Path.Combine(tempDir, "fix_ai_db.py");
                    string pyCode = 
"import sqlite3, json, os, shutil\n" +
"db_path = os.path.expandvars(r'%USERPROFILE%\\.local\\share\\opencode\\opencode.db')\n" +
"if os.path.exists(db_path):\n" +
"    try: shutil.copyfile(db_path, db_path + '.bak')\n" +
"    except: pass\n" +
"    conn = sqlite3.connect(db_path)\n" +
"    cur = conn.cursor()\n" +
"    cur.execute('DELETE FROM session_message WHERE type = \"compaction\" OR data LIKE \"%provider.free-limit%\" OR data LIKE \"%FreeUsageLimit%\";')\n" +
"    del_cnt = cur.rowcount\n" +
"    cur.execute('UPDATE session_v2 SET tokens_input = 0, tokens_output = 0, tokens_reasoning = 0, tokens_cache_read = 0, tokens_cache_write = 0, cost = 0;')\n" +
"    sess_cnt = cur.rowcount\n" +
"    conn.commit()\n" +
"    conn.close()\n" +
"    print('CLEANED_OK:' + str(del_cnt) + ':' + str(sess_cnt))\n" +
"else:\n" +
"    print('DB_NOT_FOUND')\n";

                    File.WriteAllText(pyFile, pyCode);
                    string pyOutput = RunProcessOutput("python", "\"" + pyFile + "\"");
                    try { File.Delete(pyFile); } catch {}
                    if (pyOutput.Contains("CLEANED_OK")) { Log("Database cleaned: Deleted error messages and reset all token limits."); }
                    else { Log("DB cleaner: " + pyOutput.Trim()); }

                    // 5. Rotate WARP IP if fullFix
                    if (fullFix) {
                        Log("Rotating Cloudflare WARP IP...");
                        string progFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
                        string warpCli = Path.Combine(progFiles, "Cloudflare", "Cloudflare WARP", "warp-cli.exe");
                        if (!File.Exists(warpCli)) { warpCli = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Cloudflare", "Cloudflare WARP", "warp-cli.exe"); }
                        if (File.Exists(warpCli)) {
                            RunProcess(warpCli, "disconnect"); System.Threading.Thread.Sleep(1000);
                            RunProcess(warpCli, "registration delete"); System.Threading.Thread.Sleep(1000);
                            RunProcess(warpCli, "registration new"); System.Threading.Thread.Sleep(2000);
                            RunProcess(warpCli, "connect"); System.Threading.Thread.Sleep(3500);
                        }
                    }
                } catch (Exception ex) { Log("Error: " + ex.Message); }
            });

            await RefreshInfoAsync();
            SetWorking(false, "Done!");
            Log(" Fix completed successfully!");
        }

        private async Task TestModelAsync(string modelName, string modelId)
        {
            SetWorking(true, "Testing " + modelName + "...");
            Log("Testing " + modelName + " (" + modelId + ")...");
            string r = await Task.Run(() => {
                try {
                    var psi = new ProcessStartInfo {
                        FileName = "cmd.exe",
                        Arguments = "/c echo say hi | opencode run --model " + modelId + " --format default",
                        UseShellExecute = false,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        CreateNoWindow = true
                    };
                    using (var p = Process.Start(psi)) {
                        if (p.WaitForExit(15000)) {
                            string o = p.StandardOutput.ReadToEnd();
                            string e = p.StandardError.ReadToEnd();
                            return string.IsNullOrEmpty(o) ? e : o;
                        } else {
                            try { p.Kill(); } catch {}
                            return "TIMEOUT (15s)";
                        }
                    }
                } catch (Exception ex) { return "Error: " + ex.Message; }
            });
            SetWorking(false, "Test finished.");
            Log("Response:\r\n" + r.Trim());
        }

        private void RunProcess(string f, string a)
        {
            try {
                var p = Process.Start(new ProcessStartInfo { FileName = f, Arguments = a, UseShellExecute = false, CreateNoWindow = true });
                p.WaitForExit(8000);
            } catch {}
        }

        private string RunProcessOutput(string f, string a)
        {
            try {
                var psi = new ProcessStartInfo { FileName = f, Arguments = a, UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
                using (var p = Process.Start(psi)) {
                    if (p.WaitForExit(10000)) { return p.StandardOutput.ReadToEnd() + p.StandardError.ReadToEnd(); }
                }
            } catch (Exception ex) { return ex.Message; }
            return "";
        }

        [STAThread]
        public static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }
    }
}
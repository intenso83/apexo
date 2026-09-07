using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;

[assembly: AssemblyTitle("Apexo DentalWin Migrator")]
[assembly: AssemblyDescription("Read-only DentalWin inventory and encrypted migration staging utility")]
[assembly: AssemblyCompany("Apexo")]
[assembly: AssemblyProduct("Apexo DentalWin Migrator")]
[assembly: AssemblyVersion("0.1.1.0")]
[assembly: AssemblyFileVersion("0.1.1.0")]

namespace Apexo.DentalWinMigrator
{
    internal enum MigrationOperation
    {
        Preflight,
        Inventory,
        PrivateDryRun,
        SyntheticDryRun
    }

    internal sealed class ProcessResult
    {
        public int ExitCode;
        public string StandardOutput;
        public string StandardError;
        public string ResultJson;
        public string PowerShellPath;
    }

    internal sealed class EngineOutcome
    {
        public bool Success;
        public string Message;
        public string Details;
        public string OutputDirectory;
        public string ReportPath;
        public string ResultJson;
    }

    internal sealed class EmbeddedEngine
    {
        private const string ModuleResource = "Apexo.DentalWin.Engine";
        private const string RunnerResource = "Apexo.DentalWin.Runner";
        private const string FixtureResource = "Apexo.DentalWin.Fixture";

        public async Task<EngineOutcome> ExecuteAsync(
            MigrationOperation operation,
            string sourceDirectory,
            string outputDirectory,
            string keyFile,
            Action<string> progress)
        {
            string temporaryDirectory = CreateTemporaryDirectory();
            try
            {
                string modulePath = Path.Combine(temporaryDirectory, "DentalWinMigration.psm1");
                string runnerPath = Path.Combine(temporaryDirectory, "MigrationRunner.ps1");
                string fixturePath = Path.Combine(temporaryDirectory, "synthetic_source.json");
                ExtractResource(ModuleResource, modulePath);
                ExtractResource(RunnerResource, runnerPath);
                ExtractResource(FixtureResource, fixturePath);

                List<string> candidates = GetPowerShellCandidates();
                if (candidates.Count == 0)
                {
                    return Failure("Windows PowerShell was not found.", "The utility requires the Windows PowerShell component included with supported Windows versions.");
                }

                if (operation == MigrationOperation.SyntheticDryRun)
                {
                    return await RunOperationAsync(
                        candidates[0], operation, runnerPath, modulePath,
                        sourceDirectory, outputDirectory, keyFile, fixturePath,
                        temporaryDirectory, progress);
                }

                List<ProcessResult> preflights = new List<ProcessResult>();
                string selectedPowerShell = null;
                foreach (string candidate in candidates)
                {
                    if (progress != null)
                    {
                        progress("Checking Access support with " + DescribePowerShell(candidate) + "...");
                    }
                    ProcessResult preflight = await RunPowerShellAsync(
                        candidate,
                        runnerPath,
                        modulePath,
                        "Preflight",
                        sourceDirectory,
                        null,
                        null,
                        fixturePath,
                        Path.Combine(temporaryDirectory, "preflight-" + preflights.Count + ".json"),
                        progress);
                    preflights.Add(preflight);
                    if (preflight.ExitCode == 0 && GetJsonBoolean(preflight.ResultJson, "has_access_provider"))
                    {
                        selectedPowerShell = candidate;
                        if (operation != MigrationOperation.Preflight)
                        {
                            break;
                        }
                    }
                }

                if (operation == MigrationOperation.Preflight)
                {
                    return BuildPreflightOutcome(preflights, selectedPowerShell != null);
                }

                if (selectedPowerShell == null)
                {
                    return Failure(
                        "Microsoft Access Database Engine was not found.",
                        BuildPreflightDetails(preflights) + Environment.NewLine + Environment.NewLine +
                        "Install a Microsoft ACE OLE DB provider matching either 64-bit or 32-bit Windows PowerShell, then run the compatibility check again.");
                }

                return await RunOperationAsync(
                    selectedPowerShell, operation, runnerPath, modulePath,
                    sourceDirectory, outputDirectory, keyFile, fixturePath,
                    temporaryDirectory, progress);
            }
            catch (Exception error)
            {
                return Failure("The migration utility could not start the operation.", error.Message);
            }
            finally
            {
                TryDeleteDirectory(temporaryDirectory);
            }
        }

        private async Task<EngineOutcome> RunOperationAsync(
            string powerShellPath,
            MigrationOperation operation,
            string runnerPath,
            string modulePath,
            string sourceDirectory,
            string outputDirectory,
            string keyFile,
            string fixturePath,
            string temporaryDirectory,
            Action<string> progress)
        {
            string runnerMode = operation == MigrationOperation.Inventory
                ? "Inventory"
                : operation == MigrationOperation.PrivateDryRun
                    ? "PrivateDryRun"
                    : "SyntheticDryRun";
            if (progress != null)
            {
                progress("Running " + runnerMode + " with " + DescribePowerShell(powerShellPath) + "...");
            }

            string resultPath = Path.Combine(temporaryDirectory, "operation-result.json");
            ProcessResult operationResult = await RunPowerShellAsync(
                powerShellPath,
                runnerPath,
                modulePath,
                runnerMode,
                sourceDirectory,
                outputDirectory,
                keyFile,
                fixturePath,
                resultPath,
                progress);

            bool resultSuccess = operationResult.ExitCode == 0 && GetJsonBoolean(operationResult.ResultJson, "success");
            if (!resultSuccess)
            {
                string errorMessage = GetJsonString(operationResult.ResultJson, "error");
                if (String.IsNullOrWhiteSpace(errorMessage))
                {
                    errorMessage = operationResult.StandardError;
                }
                return Failure(
                    runnerMode + " did not complete.",
                    JoinNonEmpty(operationResult.StandardOutput, errorMessage));
            }

            string completedOutput = GetJsonString(operationResult.ResultJson, "output_directory");
            if (String.IsNullOrWhiteSpace(completedOutput))
            {
                completedOutput = outputDirectory;
            }
            string reportPath = operation == MigrationOperation.Inventory
                ? Path.Combine(completedOutput, "summary.md")
                : Path.Combine(completedOutput, "reports", "summary.md");
            string report = File.Exists(reportPath)
                ? File.ReadAllText(reportPath, Encoding.UTF8)
                : operationResult.StandardOutput;

            EngineOutcome outcome = new EngineOutcome();
            outcome.Success = true;
            outcome.Message = runnerMode + " completed successfully.";
            outcome.Details = JoinNonEmpty(
                "DentalWin source hashes unchanged: " + GetJsonBoolean(operationResult.ResultJson, "source_hashes_unchanged"),
                "Writes to DentalWin: no",
                "Writes to Apexo: no",
                report);
            outcome.OutputDirectory = completedOutput;
            outcome.ReportPath = File.Exists(reportPath) ? reportPath : null;
            outcome.ResultJson = operationResult.ResultJson;
            return outcome;
        }

        private static EngineOutcome BuildPreflightOutcome(List<ProcessResult> results, bool providerFound)
        {
            int databaseCount = 0;
            foreach (ProcessResult result in results)
            {
                databaseCount = Math.Max(databaseCount, GetJsonInteger(result.ResultJson, "mdb_count"));
            }

            EngineOutcome outcome = new EngineOutcome();
            outcome.Success = providerFound && databaseCount > 0;
            outcome.Message = outcome.Success
                ? "Compatibility check passed."
                : providerFound
                    ? "Access support is available, but no .mdb databases were found in the selected folder."
                    : "Microsoft Access Database Engine was not found.";
            outcome.Details = BuildPreflightDetails(results) + Environment.NewLine + Environment.NewLine +
                "DentalWin databases found: " + databaseCount + Environment.NewLine +
                "Writes to DentalWin: no" + Environment.NewLine +
                "Writes to Apexo: no";
            return outcome;
        }

        private static string BuildPreflightDetails(List<ProcessResult> results)
        {
            StringBuilder builder = new StringBuilder();
            foreach (ProcessResult result in results)
            {
                if (builder.Length > 0)
                {
                    builder.AppendLine();
                }
                int bits = GetJsonInteger(result.ResultJson, "powershell_bits");
                bool provider = GetJsonBoolean(result.ResultJson, "has_access_provider");
                builder.Append(bits == 0 ? DescribePowerShell(result.PowerShellPath) : bits + "-bit Windows PowerShell");
                builder.Append(": ");
                builder.Append(provider ? "ACE provider available" : "ACE provider not available");
                string providers = GetJsonArrayDisplay(result.ResultJson, "access_providers");
                if (!String.IsNullOrWhiteSpace(providers))
                {
                    builder.Append(" (");
                    builder.Append(providers);
                    builder.Append(")");
                }
                if (result.ExitCode != 0 && !String.IsNullOrWhiteSpace(result.StandardError))
                {
                    builder.Append(" — ");
                    builder.Append(result.StandardError.Trim());
                }
            }
            return builder.ToString();
        }

        private static async Task<ProcessResult> RunPowerShellAsync(
            string powerShellPath,
            string runnerPath,
            string modulePath,
            string mode,
            string sourceDirectory,
            string outputDirectory,
            string keyFile,
            string fixturePath,
            string resultPath,
            Action<string> progress)
        {
            StringBuilder arguments = new StringBuilder();
            arguments.Append("-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File ");
            arguments.Append(QuoteArgument(runnerPath));
            AppendArgument(arguments, "-Mode", mode);
            AppendArgument(arguments, "-ModulePath", modulePath);
            AppendArgument(arguments, "-ResultPath", resultPath);
            AppendArgument(arguments, "-SourceDirectory", sourceDirectory);
            AppendArgument(arguments, "-OutputDirectory", outputDirectory);
            AppendArgument(arguments, "-KeyFile", keyFile);
            AppendArgument(arguments, "-FixturePath", fixturePath);

            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.FileName = powerShellPath;
            startInfo.Arguments = arguments.ToString();
            startInfo.UseShellExecute = false;
            startInfo.CreateNoWindow = true;
            startInfo.RedirectStandardOutput = true;
            startInfo.RedirectStandardError = true;
            startInfo.StandardOutputEncoding = Encoding.UTF8;
            startInfo.StandardErrorEncoding = Encoding.UTF8;

            Process process = new Process();
            process.StartInfo = startInfo;
            StringBuilder standardOutput = new StringBuilder();
            StringBuilder standardError = new StringBuilder();
            process.OutputDataReceived += delegate(object sender, DataReceivedEventArgs args)
            {
                if (args.Data != null)
                {
                    standardOutput.AppendLine(args.Data);
                }
            };
            process.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs args)
            {
                if (args.Data != null)
                {
                    standardError.AppendLine(args.Data);
                }
            };

            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();
            await Task.Run(delegate { process.WaitForExit(); });
            process.WaitForExit();

            ProcessResult result = new ProcessResult();
            result.ExitCode = process.ExitCode;
            result.StandardOutput = standardOutput.ToString().Trim();
            result.StandardError = standardError.ToString().Trim();
            result.ResultJson = File.Exists(resultPath)
                ? File.ReadAllText(resultPath, Encoding.UTF8)
                : String.Empty;
            result.PowerShellPath = powerShellPath;
            process.Dispose();
            return result;
        }

        private static List<string> GetPowerShellCandidates()
        {
            List<string> candidates = new List<string>();
            string windows = Environment.GetEnvironmentVariable("WINDIR");
            if (String.IsNullOrWhiteSpace(windows))
            {
                string system = Environment.GetFolderPath(Environment.SpecialFolder.System);
                DirectoryInfo parent = Directory.GetParent(system);
                windows = parent == null ? system : parent.FullName;
            }
            AddCandidate(candidates, Path.Combine(windows, "System32", "WindowsPowerShell", "v1.0", "powershell.exe"));
            AddCandidate(candidates, Path.Combine(windows, "SysWOW64", "WindowsPowerShell", "v1.0", "powershell.exe"));
            return candidates;
        }

        private static void AddCandidate(List<string> candidates, string path)
        {
            if (File.Exists(path) && !candidates.Contains(path))
            {
                candidates.Add(path);
            }
        }

        private static string DescribePowerShell(string path)
        {
            if (String.IsNullOrWhiteSpace(path))
            {
                return "Windows PowerShell";
            }
            return path.IndexOf("SysWOW64", StringComparison.OrdinalIgnoreCase) >= 0
                ? "32-bit Windows PowerShell"
                : "64-bit Windows PowerShell";
        }

        private static void AppendArgument(StringBuilder builder, string name, string value)
        {
            if (String.IsNullOrWhiteSpace(value))
            {
                return;
            }
            builder.Append(' ');
            builder.Append(name);
            builder.Append(' ');
            builder.Append(QuoteArgument(value));
        }

        private static string QuoteArgument(string value)
        {
            if (value.IndexOf('"') >= 0)
            {
                throw new ArgumentException("Paths containing quotation marks are not supported.");
            }
            return "\"" + value + "\"";
        }

        private static string CreateTemporaryDirectory()
        {
            string path = Path.Combine(Path.GetTempPath(), "ApexoDentalWinMigrator", Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(path);
            return path;
        }

        private static void ExtractResource(string resourceName, string destination)
        {
            Assembly assembly = Assembly.GetExecutingAssembly();
            using (Stream input = assembly.GetManifestResourceStream(resourceName))
            {
                if (input == null)
                {
                    throw new InvalidOperationException("Embedded migration resource is missing: " + resourceName);
                }
                // Windows PowerShell 5.1 treats a UTF-8 script without a BOM as
                // the current ANSI code page. Re-emit every embedded text
                // resource as UTF-8 with a BOM so Greek DentalWin labels remain
                // valid PowerShell syntax on both 32-bit and 64-bit hosts.
                using (StreamReader reader = new StreamReader(
                    input,
                    new UTF8Encoding(false, true),
                    true))
                {
                    File.WriteAllText(
                        destination,
                        reader.ReadToEnd(),
                        new UTF8Encoding(true));
                }
            }
        }

        private static void TryDeleteDirectory(string path)
        {
            try
            {
                if (Directory.Exists(path))
                {
                    Directory.Delete(path, true);
                }
            }
            catch
            {
                // Temporary extraction contains code and synthetic fixtures only.
            }
        }

        private static EngineOutcome Failure(string message, string details)
        {
            EngineOutcome outcome = new EngineOutcome();
            outcome.Success = false;
            outcome.Message = message;
            outcome.Details = details;
            return outcome;
        }

        private static Dictionary<string, object> ParseJson(string json)
        {
            if (String.IsNullOrWhiteSpace(json))
            {
                return new Dictionary<string, object>();
            }
            try
            {
                JavaScriptSerializer serializer = new JavaScriptSerializer();
                Dictionary<string, object> parsed = serializer.DeserializeObject(json) as Dictionary<string, object>;
                return parsed ?? new Dictionary<string, object>();
            }
            catch
            {
                return new Dictionary<string, object>();
            }
        }

        private static bool GetJsonBoolean(string json, string name)
        {
            Dictionary<string, object> parsed = ParseJson(json);
            object value;
            if (!parsed.TryGetValue(name, out value) || value == null)
            {
                return false;
            }
            bool result;
            return Boolean.TryParse(value.ToString(), out result) && result;
        }

        private static int GetJsonInteger(string json, string name)
        {
            Dictionary<string, object> parsed = ParseJson(json);
            object value;
            int result;
            return parsed.TryGetValue(name, out value) && value != null && Int32.TryParse(value.ToString(), out result)
                ? result
                : 0;
        }

        private static string GetJsonString(string json, string name)
        {
            Dictionary<string, object> parsed = ParseJson(json);
            object value;
            return parsed.TryGetValue(name, out value) && value != null ? value.ToString() : String.Empty;
        }

        private static string GetJsonArrayDisplay(string json, string name)
        {
            Dictionary<string, object> parsed = ParseJson(json);
            object value;
            if (!parsed.TryGetValue(name, out value) || value == null)
            {
                return String.Empty;
            }
            object[] values = value as object[];
            if (values == null)
            {
                return value.ToString();
            }
            List<string> text = new List<string>();
            foreach (object item in values)
            {
                if (item != null)
                {
                    text.Add(item.ToString());
                }
            }
            return String.Join(", ", text.ToArray());
        }

        private static string JoinNonEmpty(params string[] values)
        {
            List<string> nonEmpty = new List<string>();
            foreach (string value in values)
            {
                if (!String.IsNullOrWhiteSpace(value))
                {
                    nonEmpty.Add(value.Trim());
                }
            }
            return String.Join(Environment.NewLine + Environment.NewLine, nonEmpty.ToArray());
        }
    }

    internal sealed class MainForm : Form
    {
        private readonly TextBox sourceTextBox;
        private readonly TextBox outputTextBox;
        private readonly TextBox logTextBox;
        private readonly Button checkButton;
        private readonly Button inventoryButton;
        private readonly Button dryRunButton;
        private readonly Button openReportButton;
        private readonly Button openOutputButton;
        private readonly ProgressBar progressBar;
        private readonly Label statusLabel;
        private readonly EmbeddedEngine engine;
        private bool busy;
        private string lastOutputDirectory;
        private string lastReportPath;

        public MainForm()
        {
            engine = new EmbeddedEngine();
            Text = "Apexo DentalWin Migrator";
            Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            MinimumSize = new Size(900, 680);
            Size = new Size(980, 760);
            StartPosition = FormStartPosition.CenterScreen;
            Font = new Font("Segoe UI", 9F, FontStyle.Regular, GraphicsUnit.Point);
            BackColor = Color.FromArgb(245, 247, 249);

            Panel header = new Panel();
            header.Dock = DockStyle.Top;
            header.Height = 84;
            header.BackColor = Color.FromArgb(19, 78, 74);
            Controls.Add(header);

            Label title = new Label();
            title.Text = "Apexo • DentalWin Migration Utility";
            title.ForeColor = Color.White;
            title.Font = new Font("Segoe UI Semibold", 19F, FontStyle.Bold);
            title.AutoSize = true;
            title.Location = new Point(24, 14);
            header.Controls.Add(title);

            Label subtitle = new Label();
            subtitle.Text = "Ασφαλής απογραφή και κρυπτογραφημένη προετοιμασία μεταφοράς • Read-only source processing";
            subtitle.ForeColor = Color.FromArgb(204, 251, 241);
            subtitle.AutoSize = true;
            subtitle.Location = new Point(27, 53);
            header.Controls.Add(subtitle);

            TableLayoutPanel layout = new TableLayoutPanel();
            layout.Dock = DockStyle.Fill;
            layout.Padding = new Padding(24, 18, 24, 18);
            layout.ColumnCount = 1;
            layout.RowCount = 7;
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 72));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 78));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 78));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 62));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 52));
            layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 42));
            Controls.Add(layout);
            layout.BringToFront();

            Label notice = new Label();
            notice.Dock = DockStyle.Fill;
            notice.Padding = new Padding(12, 9, 12, 9);
            notice.BackColor = Color.FromArgb(255, 247, 237);
            notice.ForeColor = Color.FromArgb(124, 45, 18);
            notice.BorderStyle = BorderStyle.FixedSingle;
            notice.Text = "Use a verified COPY of the DentalWin folder—not the live clinic folder. The utility opens .mdb files read-only and verifies their hashes before and after extraction.";
            notice.TextAlign = ContentAlignment.MiddleLeft;
            layout.Controls.Add(notice, 0, 0);

            sourceTextBox = AddFolderRow(
                layout,
                1,
                "1. DentalWin source copy / Αντίγραφο φακέλου DentalWin",
                "Select the folder containing dental.mdb, Schedule.mdb, DentalInfo.mdb and farmaka.mdb.",
                BrowseSource);

            string defaultOutput = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Apexo",
                "DentalWinMigrator",
                "Runs");
            outputTextBox = AddFolderRow(
                layout,
                2,
                "2. Private output location / Ιδιωτικός φάκελος αποτελεσμάτων",
                "Aggregate reports and encrypted staging are stored here. A new run folder is created automatically.",
                BrowseOutput);
            outputTextBox.Text = defaultOutput;

            FlowLayoutPanel actions = new FlowLayoutPanel();
            actions.Dock = DockStyle.Fill;
            actions.FlowDirection = FlowDirection.LeftToRight;
            actions.WrapContents = false;
            actions.Padding = new Padding(0, 8, 0, 4);
            layout.Controls.Add(actions, 0, 3);

            checkButton = CreateActionButton("1  Compatibility check", Color.FromArgb(71, 85, 105));
            inventoryButton = CreateActionButton("2  Read-only inventory", Color.FromArgb(14, 116, 144));
            dryRunButton = CreateActionButton("3  Encrypted dry run", Color.FromArgb(13, 148, 136));
            checkButton.Click += async delegate { await RunOperationAsync(MigrationOperation.Preflight); };
            inventoryButton.Click += async delegate { await RunOperationAsync(MigrationOperation.Inventory); };
            dryRunButton.Click += async delegate { await RunOperationAsync(MigrationOperation.PrivateDryRun); };
            actions.Controls.Add(checkButton);
            actions.Controls.Add(inventoryButton);
            actions.Controls.Add(dryRunButton);

            Panel statusPanel = new Panel();
            statusPanel.Dock = DockStyle.Fill;
            layout.Controls.Add(statusPanel, 0, 4);
            statusLabel = new Label();
            statusLabel.Text = "Ready. Start with the compatibility check.";
            statusLabel.AutoEllipsis = true;
            statusLabel.Dock = DockStyle.Top;
            statusLabel.Height = 24;
            statusPanel.Controls.Add(statusLabel);
            progressBar = new ProgressBar();
            progressBar.Dock = DockStyle.Bottom;
            progressBar.Height = 16;
            progressBar.Style = ProgressBarStyle.Blocks;
            statusPanel.Controls.Add(progressBar);

            logTextBox = new TextBox();
            logTextBox.Dock = DockStyle.Fill;
            logTextBox.Multiline = true;
            logTextBox.ReadOnly = true;
            logTextBox.ScrollBars = ScrollBars.Both;
            logTextBox.WordWrap = false;
            logTextBox.BackColor = Color.White;
            logTextBox.Font = new Font("Consolas", 9F);
            logTextBox.Text =
                "This standalone version prepares and validates the migration.\r\n" +
                "It does not write to DentalWin and does not connect to Apexo production.\r\n\r\n" +
                "Why: Apexo's final versioned medical-history destination is still under development.\r\n" +
                "Clinical data will not be forced into an incorrect temporary field.";
            layout.Controls.Add(logTextBox, 0, 5);

            FlowLayoutPanel footer = new FlowLayoutPanel();
            footer.Dock = DockStyle.Fill;
            footer.FlowDirection = FlowDirection.RightToLeft;
            footer.WrapContents = false;
            layout.Controls.Add(footer, 0, 6);
            openReportButton = new Button();
            openReportButton.Text = "Open aggregate report";
            openReportButton.AutoSize = true;
            openReportButton.Enabled = false;
            openReportButton.Click += OpenReport;
            openOutputButton = new Button();
            openOutputButton.Text = "Open output folder";
            openOutputButton.AutoSize = true;
            openOutputButton.Enabled = false;
            openOutputButton.Click += OpenOutput;
            Label version = new Label();
            version.Text = "v0.1 • source read-only • encrypted staging";
            version.AutoSize = true;
            version.Padding = new Padding(0, 8, 18, 0);
            version.ForeColor = Color.DimGray;
            footer.Controls.Add(openReportButton);
            footer.Controls.Add(openOutputButton);
            footer.Controls.Add(version);
        }

        private TextBox AddFolderRow(
            TableLayoutPanel parent,
            int row,
            string title,
            string description,
            EventHandler browseHandler)
        {
            Panel panel = new Panel();
            panel.Dock = DockStyle.Fill;
            parent.Controls.Add(panel, 0, row);

            Label titleLabel = new Label();
            titleLabel.Text = title;
            titleLabel.Font = new Font("Segoe UI Semibold", 9.5F, FontStyle.Bold);
            titleLabel.AutoSize = true;
            titleLabel.Location = new Point(0, 2);
            panel.Controls.Add(titleLabel);

            TextBox textBox = new TextBox();
            textBox.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
            textBox.Location = new Point(0, 27);
            textBox.Width = panel.Width - 112;
            panel.Controls.Add(textBox);

            Button browse = new Button();
            browse.Text = "Browse...";
            browse.Anchor = AnchorStyles.Top | AnchorStyles.Right;
            browse.Location = new Point(panel.Width - 100, 25);
            browse.Width = 100;
            browse.Click += browseHandler;
            panel.Controls.Add(browse);

            Label descriptionLabel = new Label();
            descriptionLabel.Text = description;
            descriptionLabel.ForeColor = Color.DimGray;
            descriptionLabel.AutoSize = true;
            descriptionLabel.Location = new Point(0, 55);
            panel.Controls.Add(descriptionLabel);
            return textBox;
        }

        private static Button CreateActionButton(string text, Color backColor)
        {
            Button button = new Button();
            button.Text = text;
            button.AutoSize = true;
            button.Height = 38;
            button.Padding = new Padding(12, 0, 12, 0);
            button.FlatStyle = FlatStyle.Flat;
            button.FlatAppearance.BorderSize = 0;
            button.BackColor = backColor;
            button.ForeColor = Color.White;
            button.Margin = new Padding(0, 0, 12, 0);
            return button;
        }

        private void BrowseSource(object sender, EventArgs args)
        {
            BrowseInto(sourceTextBox, "Select the copied DentalWin folder");
        }

        private void BrowseOutput(object sender, EventArgs args)
        {
            BrowseInto(outputTextBox, "Select a private output location");
        }

        private static void BrowseInto(TextBox target, string description)
        {
            using (FolderBrowserDialog dialog = new FolderBrowserDialog())
            {
                dialog.Description = description;
                dialog.ShowNewFolderButton = true;
                if (Directory.Exists(target.Text))
                {
                    dialog.SelectedPath = target.Text;
                }
                if (dialog.ShowDialog() == DialogResult.OK)
                {
                    target.Text = dialog.SelectedPath;
                }
            }
        }

        private async Task RunOperationAsync(MigrationOperation operation)
        {
            if (busy)
            {
                return;
            }

            string source = sourceTextBox.Text.Trim();
            string outputRoot = outputTextBox.Text.Trim();
            if (!Directory.Exists(source))
            {
                MessageBox.Show(this, "Select an existing copied DentalWin folder first.", "Source folder required", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            if (String.IsNullOrWhiteSpace(outputRoot))
            {
                MessageBox.Show(this, "Select a private output folder.", "Output folder required", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            string outputDirectory = null;
            string keyFile = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Apexo",
                "DentalWinMigrator",
                "Keys",
                "dentalwin-staging.key");
            if (operation != MigrationOperation.Preflight)
            {
                Directory.CreateDirectory(outputRoot);
                string prefix = operation == MigrationOperation.Inventory ? "inventory" : "private-dry-run";
                outputDirectory = Path.Combine(
                    outputRoot,
                    prefix + "-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + "-" + Guid.NewGuid().ToString("N").Substring(0, 6));
            }

            SetBusy(true);
            lastOutputDirectory = null;
            lastReportPath = null;
            logTextBox.Text = "Starting " + operation + "...\r\n";
            try
            {
                EngineOutcome outcome = await engine.ExecuteAsync(
                    operation,
                    source,
                    outputDirectory,
                    keyFile,
                    delegate(string message)
                    {
                        BeginInvoke((MethodInvoker)delegate
                        {
                            statusLabel.Text = message;
                        });
                    });

                statusLabel.Text = outcome.Message;
                logTextBox.Text = outcome.Message + "\r\n\r\n" + outcome.Details;
                lastOutputDirectory = outcome.OutputDirectory;
                lastReportPath = outcome.ReportPath;
                openOutputButton.Enabled = !String.IsNullOrWhiteSpace(lastOutputDirectory) && Directory.Exists(lastOutputDirectory);
                openReportButton.Enabled = !String.IsNullOrWhiteSpace(lastReportPath) && File.Exists(lastReportPath);
                if (!outcome.Success)
                {
                    MessageBox.Show(this, outcome.Message + "\r\n\r\n" + outcome.Details, "Operation needs attention", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                }
            }
            catch (Exception error)
            {
                statusLabel.Text = "Operation failed.";
                logTextBox.Text = error.ToString();
                MessageBox.Show(this, error.Message, "Migration utility error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                SetBusy(false);
            }
        }

        private void SetBusy(bool value)
        {
            busy = value;
            checkButton.Enabled = !value;
            inventoryButton.Enabled = !value;
            dryRunButton.Enabled = !value;
            sourceTextBox.Enabled = !value;
            outputTextBox.Enabled = !value;
            progressBar.Style = value ? ProgressBarStyle.Marquee : ProgressBarStyle.Blocks;
            if (!value)
            {
                progressBar.Value = 0;
            }
        }

        private void OpenReport(object sender, EventArgs args)
        {
            OpenPath(lastReportPath, true);
        }

        private void OpenOutput(object sender, EventArgs args)
        {
            OpenPath(lastOutputDirectory, false);
        }

        private void OpenPath(string path, bool selectFileOnFailure)
        {
            if (String.IsNullOrWhiteSpace(path) || (!File.Exists(path) && !Directory.Exists(path)))
            {
                return;
            }
            try
            {
                ProcessStartInfo info = new ProcessStartInfo();
                info.FileName = path;
                info.UseShellExecute = true;
                Process.Start(info);
            }
            catch
            {
                string arguments = selectFileOnFailure ? "/select,\"" + path + "\"" : "\"" + path + "\"";
                Process.Start("explorer.exe", arguments);
            }
        }
    }

    internal static class Program
    {
        [STAThread]
        private static void Main(string[] args)
        {
            if (args.Length >= 2 && String.Equals(args[0], "--engine-self-test", StringComparison.OrdinalIgnoreCase))
            {
                RunSelfTest(args[1]);
                return;
            }

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }

        private static void RunSelfTest(string outputDirectory)
        {
            try
            {
                EmbeddedEngine engine = new EmbeddedEngine();
                EngineOutcome outcome = engine.ExecuteAsync(
                    MigrationOperation.SyntheticDryRun,
                    null,
                    outputDirectory,
                    null,
                    null).GetAwaiter().GetResult();
                string resultPath = outputDirectory + ".self-test.txt";
                File.WriteAllText(
                    resultPath,
                    outcome.Message + Environment.NewLine + outcome.Details,
                    Encoding.UTF8);
                Environment.ExitCode = outcome.Success ? 0 : 1;
            }
            catch (Exception error)
            {
                File.WriteAllText(outputDirectory + ".self-test.txt", error.ToString(), Encoding.UTF8);
                Environment.ExitCode = 1;
            }
        }
    }
}

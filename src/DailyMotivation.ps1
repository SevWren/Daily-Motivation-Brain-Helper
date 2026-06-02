# =============================================================================
# DailyMotivation.ps1 - Debug-hardened build
# All diagnostic output goes to $env:TEMP\DailyMotivation_debug.log
# (guaranteed writable even when script path is wrong or Task Scheduler
#  working directory is C:\Windows\System32)
# NOTE: ASCII-only characters throughout - no smart quotes or em dashes.
#       Windows PowerShell 5.1 reads scripts as Windows-1252 when no BOM
#       is present; UTF-8 multi-byte sequences (em dash, curly quotes) cause
#       silent parse failures before line 1 executes.
# =============================================================================

# --- Step 0: Establish debug log BEFORE anything can fail ---
$debugLog     = Join-Path $env:TEMP "DailyMotivation_debug.log"
$errorLogPath = Join-Path $env:TEMP "DailyMotivation_error.log"

function Write-DLog {
    param([string]$Msg, [string]$Level = "INFO")
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Msg"
    Add-Content -Path $debugLog -Value $line -ErrorAction SilentlyContinue
}

Write-DLog "====== SCRIPT STARTED ======"
Write-DLog "User=$env:USERNAME | Computer=$env:COMPUTERNAME | PID=$PID"
Write-DLog "PowerShell=$($PSVersionTable.PSVersion) | STA=$([System.Threading.Thread]::CurrentThread.ApartmentState)"

# --- Step 1: Load WPF assemblies (BEFORE trap, so wrap explicitly) ---
try {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    Write-DLog "WPF assemblies loaded OK"
} catch {
    Write-DLog "FATAL: WPF assembly load failed - $_" "ERROR"
    exit 1
}

# --- Step 2: Paths - use $PSScriptRoot (reliable under Task Scheduler -File) ---
$scriptDir  = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$configPath = Join-Path $scriptDir "popup_config.json"
$logPath    = Join-Path $scriptDir "popup_log.txt"

Write-DLog "PSScriptRoot='$PSScriptRoot'"
Write-DLog "InvocationDef='$($MyInvocation.MyCommand.Definition)'"
Write-DLog "Resolved scriptDir='$scriptDir'"
Write-DLog "configPath='$configPath'"
Write-DLog "logPath='$logPath'"

# --- Step 3: Trap for any uncaught exception after this point ---
trap {
    Write-DLog "UNCAUGHT EXCEPTION: $_" "ERROR"
    Add-Content -Path $errorLogPath -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR: $_" -ErrorAction SilentlyContinue
    break
}

# --- Step 4: Load config ---
$config = [PSCustomObject]@{
    title         = "Time to Show Up"
    body          = "Every great outcome starts with showing up. You already did the hardest part - let's make this session count."
    glyph         = "[+]"
    explorer_path = ""
}

if (Test-Path $configPath) {
    Write-DLog "Config file found at $configPath - loading..."
    try {
#        $loaded = Get-Content $configPath -Raw | ConvertFrom-Json
        $loaded = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

        $config = $loaded
        Write-DLog "Config loaded OK. title='$($config.title)'"
    } catch {
        Write-DLog "Config parse failed - using defaults" "WARN"
    }
} else {
    Write-DLog "Config file NOT found at '$configPath' - using hardcoded defaults" "WARN"
}

# --- Step 5: XAML ---
[xml]$xaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    WindowStyle="None"
    AllowsTransparency="True"
    Background="Transparent"
    Width="480"
    SizeToContent="Height"
    WindowStartupLocation="CenterScreen"
    Topmost="True"
    ShowInTaskbar="False"
    ResizeMode="NoResize"
    Opacity="0">

    <Border Background="#14141F" CornerRadius="14" Padding="32,28,32,28">
        <Border.Effect>
            <DropShadowEffect Color="Black" BlurRadius="48" ShadowDepth="0" Opacity="0.85"/>
        </Border.Effect>
        <StackPanel>

            <!-- Accent bar -->
            <Border Background="#00BCD4" Height="3" CornerRadius="2" Margin="0,0,0,22"/>

            <!-- Glyph + Title row -->
            <StackPanel Orientation="Horizontal" Margin="0,0,0,14">
                <TextBlock x:Name="GlyphText"
                           FontSize="26" Foreground="#00BCD4"
                           VerticalAlignment="Center" Margin="0,0,12,0"/>
                <TextBlock x:Name="TitleText"
                           FontSize="19" FontWeight="Bold"
                           Foreground="#E8E8F4" VerticalAlignment="Center"
                           TextWrapping="Wrap" MaxWidth="370"/>
            </StackPanel>

            <!-- Body text -->
            <TextBlock x:Name="BodyText"
                       FontSize="14" Foreground="#8888A8"
                       TextWrapping="Wrap" LineHeight="23"
                       Margin="0,0,0,26"/>

            <!-- Divider -->
            <Border Background="#1F1F30" Height="1" Margin="0,0,0,18"/>

            <!-- Countdown row -->
            <StackPanel Orientation="Horizontal" Margin="0,0,0,22">
                <TextBlock Text="Auto-opening in "
                           FontSize="12" Foreground="#3E3E58"
                           VerticalAlignment="Center"/>
                <TextBlock x:Name="CountdownText" Text="20"
                           FontSize="12" FontWeight="Bold"
                           Foreground="#00BCD4" VerticalAlignment="Center"/>
                <TextBlock Text="s"
                           FontSize="12" Foreground="#3E3E58"
                           VerticalAlignment="Center"/>
            </StackPanel>

            <!-- Buttons -->
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                <Button x:Name="SnoozeBtn"
                        Content="Snooze" Width="110" Height="38"
                        Foreground="#555570" FontSize="13" FontWeight="SemiBold"
                        Background="#1C1C2C" BorderBrush="#2A2A42" BorderThickness="1"
                        Cursor="Hand" Margin="0,0,12,0">
                    <Button.Template>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}"
                                    BorderBrush="{TemplateBinding BorderBrush}"
                                    BorderThickness="{TemplateBinding BorderThickness}"
                                    CornerRadius="7">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                        </ControlTemplate>
                    </Button.Template>
                </Button>

                <Button x:Name="LetsGoBtn"
                        Content="Let's Go >" Width="130" Height="38"
                        Foreground="#0D1117" FontSize="14" FontWeight="Bold"
                        Background="#00BCD4" BorderThickness="0"
                        Cursor="Hand">
                    <Button.Template>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}" CornerRadius="7">
                                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                        </ControlTemplate>
                    </Button.Template>
                </Button>
            </StackPanel>

        </StackPanel>
    </Border>
</Window>
'@

# --- Step 6: Build window (with null-guard) ---
Write-DLog "Parsing XAML and building window..."
try {
    $reader = [System.Xml.XmlNodeReader]::new($xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    Write-DLog "FATAL: XAML parse / window build failed - $_" "ERROR"
    exit 1
}

if ($null -eq $window) {
    Write-DLog "FATAL: XamlReader returned null window object" "ERROR"
    exit 1
}
Write-DLog "Window object created OK"

$window.FindName("GlyphText").Text = $config.glyph
$window.FindName("TitleText").Text = $config.title
$window.FindName("BodyText").Text  = $config.body
Write-DLog "UI text fields populated"

# --- Step 7: State ---
$script:openExplorer = $true
$script:remaining    = 20

# --- Step 8: Fade-in on Loaded ---
$window.Add_Loaded({
    try {
        $anim = [System.Windows.Media.Animation.DoubleAnimation]::new(
            0, 1,
            [System.Windows.Duration]::new([System.TimeSpan]::FromMilliseconds(300))
        )
        $window.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $anim)
        Write-DLog "Fade-in animation started"
    } catch {
        Write-DLog "Fade-in animation failed (non-fatal) - $_" "WARN"
    }
})

# --- Step 9: Countdown timer ---
$timer          = [System.Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [System.TimeSpan]::FromSeconds(1)
$script:firstTick = $true
$timer.Add_Tick({
    try {
        if ($script:firstTick) {
            Write-DLog "Timer first tick fired - countdown running"
            $script:firstTick = $false
        }
        $script:remaining--
        $window.FindName("CountdownText").Text = $script:remaining
        if ($script:remaining -le 0) {
            $timer.Stop()
            $script:openExplorer = $true
            $window.Close()
        }
    } catch {
        Write-DLog "ERROR in timer tick - $_" "ERROR"
        $timer.Stop()
        $window.Close()
    }
})
$timer.Start()
Write-DLog "DispatcherTimer started"

# --- Step 10: Button handlers ---
$window.FindName("LetsGoBtn").Add_Click({
    try {
        Write-DLog "LetsGo clicked"
        $timer.Stop()
        $script:openExplorer = $true
        $window.Close()
    } catch {
        Write-DLog "ERROR in LetsGo click - $_" "ERROR"
    }
})

$window.FindName("SnoozeBtn").Add_Click({
    try {
        Write-DLog "Snooze clicked"
        $timer.Stop()
        $script:openExplorer = $false
        $window.Close()
    } catch {
        Write-DLog "ERROR in Snooze click - $_" "ERROR"
    }
})

# --- Step 11: Show ---
Write-DLog "Calling ShowDialog() - window should appear now"
try {
    $window.ShowDialog() | Out-Null
    Write-DLog "ShowDialog() returned - openExplorer=$($script:openExplorer)"
} catch {
    Write-DLog "FATAL: ShowDialog() threw - $_" "ERROR"
    exit 1
}

# --- Step 12: Post-close: open Explorer if applicable ---
if ($script:openExplorer -and $config.explorer_path -and ($config.explorer_path -ne "")) {
    Write-DLog "Launching Explorer: $($config.explorer_path)"
    try {
        Start-Process "explorer.exe" -ArgumentList $config.explorer_path -ErrorAction Stop
        Write-DLog "Explorer launched OK"
    } catch {
        Write-DLog "Explorer launch failed - $_" "ERROR"
    }
} else {
    Write-DLog "Explorer launch skipped (snoozed or no path configured)"
}

# --- Step 13: Final outcome log ---
$outcome = if ($script:openExplorer) { "Opened Explorer" } else { "Snoozed" }
$entry   = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] | $($config.title) | $outcome"
try {
    Add-Content -Path $logPath -Value $entry -ErrorAction Stop
    Write-DLog "Outcome written to popup_log.txt"
} catch {
    Write-DLog "Could not write to popup_log.txt - $_" "WARN"
    Write-DLog "OUTCOME (fallback): $entry"
}

Write-DLog "====== SCRIPT COMPLETE ======"

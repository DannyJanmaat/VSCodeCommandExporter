$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputFile = Join-Path $scriptDir "vscode-commands.txt"
$tempFolder = Join-Path $env:TEMP "VSCodeCommandExtractor"

if (Test-Path $tempFolder) { Remove-Item -Path $tempFolder -Recurse -Force -ErrorAction SilentlyContinue >$null }
New-Item -ItemType Directory -Path $tempFolder -Force >$null 2>&1

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WindowHelper {
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    
    public const int SW_MINIMIZE = 6;
    public const int SW_HIDE = 0;
}
"@ -ErrorAction SilentlyContinue

function Minimize-Windows {
    param([string]$ProcessName)
    
    Get-Process $ProcessName -ErrorAction SilentlyContinue | ForEach-Object {
        [void][WindowHelper]::ShowWindow($_.MainWindowHandle, [WindowHelper]::SW_MINIMIZE)
    }
}

$extensionContent = @'
const vscode = require('vscode');
const fs = require('fs');

function activate(context) {
    const outputFile = process.env.VSCODE_COMMAND_OUTPUT;
    
    setTimeout(() => {
        vscode.commands.getCommands(true).then(commands => {
            commands.sort();
            fs.writeFileSync(outputFile, commands.join('\n'), { flag: 'w' });
            fs.writeFileSync(outputFile + ".done", "done");
            
            setTimeout(() => {
                vscode.commands.executeCommand('workbench.action.closeWindow');
            }, 2000);
        });
    }, 5000);
}

function deactivate() {}

module.exports = { activate, deactivate };
'@

$packageContent = @'
{
    "name": "vscode-command-extractor",
    "displayName": "VS Code Command Extractor",
    "description": "Automatically exports all VS Code commands",
    "version": "0.0.1",
    "engines": {"vscode": "^1.60.0"},
    "activationEvents": ["*"],
    "main": "./extension.js"
}
'@

$launchContent = @'
{
    "version": "0.2.0",
    "configurations": [{
        "name": "Extension",
        "type": "extensionHost",
        "request": "launch",
        "args": ["--extensionDevelopmentPath=${workspaceFolder}"],
        "outFiles": ["${workspaceFolder}/**/*.js"]
    }]
}
'@

$tasksContent = @'
{
    "version": "2.0.0",
    "tasks": [{
        "label": "Auto-Start Debugging",
        "type": "shell",
        "command": "${command:workbench.action.debug.start}",
        "runOptions": {"runOn": "folderOpen"}
    }]
}
'@

New-Item -Path $tempFolder -Name "extension.js" -ItemType "file" -Value $extensionContent -Force >$null 2>&1
New-Item -Path $tempFolder -Name "package.json" -ItemType "file" -Value $packageContent -Force >$null 2>&1

$vscodeFolderPath = Join-Path $tempFolder ".vscode"
New-Item -ItemType Directory -Path $vscodeFolderPath -Force >$null 2>&1
New-Item -Path $vscodeFolderPath -Name "launch.json" -ItemType "file" -Value $launchContent -Force >$null 2>&1
New-Item -Path $vscodeFolderPath -Name "tasks.json" -ItemType "file" -Value $tasksContent -Force >$null 2>&1

$env:VSCODE_COMMAND_OUTPUT = $outputFile

$flagFile = "$outputFile.done"
if (Test-Path $flagFile) { Remove-Item -Path $flagFile -Force >$null 2>&1 }
if (Test-Path $outputFile) { Remove-Item -Path $outputFile -Force >$null 2>&1 }

$vscodeProcessesBefore = Get-Process "Code" -ErrorAction SilentlyContinue

try {
    $codeProc = Start-Process -FilePath "code" -ArgumentList "--new-window", "`"$tempFolder`"", "--disable-workspace-trust" -PassThru
} catch {
    try {
        $codeProc = Start-Process -FilePath "code.cmd" -ArgumentList "--new-window", "`"$tempFolder`"", "--disable-workspace-trust" -PassThru
    } catch {
        Write-Host "Error launching VS Code. Make sure it's installed and 'code' is in your PATH." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Starting VS Code command extraction..." -ForegroundColor Cyan
Write-Host "Commands will be saved to: $outputFile" -ForegroundColor Cyan

Start-Sleep -Seconds 2
Minimize-Windows -ProcessName "Code"

$keepMinimizingScript = {
    param($interval)
    
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WindowHelper {
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    
    public const int SW_MINIMIZE = 6;
}
"@
    
    while ($true) {
        Get-Process "Code" -ErrorAction SilentlyContinue | ForEach-Object {
            [void][WindowHelper]::ShowWindow($_.MainWindowHandle, [WindowHelper]::SW_MINIMIZE)
        }
        Start-Sleep -Seconds $interval
    }
}

$minimizeJob = Start-Job -ScriptBlock $keepMinimizingScript -ArgumentList 1
Start-Sleep -Seconds 2

Start-Sleep -Seconds 3
Minimize-Windows -ProcessName "Code"

Start-Sleep -Seconds 1
$vscodeProcess = Get-Process "Code" | Where-Object { $vscodeProcessesBefore -notcontains $_ }
if ($vscodeProcess) {
    foreach ($proc in $vscodeProcess) {
        if ($proc.MainWindowHandle -ne [IntPtr]::Zero) {
            [void][WindowHelper]::ShowWindow($proc.MainWindowHandle, [WindowHelper]::SW_MINIMIZE)
        }
    }
}

$pressF5Script = Join-Path $tempFolder "pressF5.ps1"
$pressF5Content = @'
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class KeyboardSend
{
    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, int dwFlags, int dwExtraInfo);
    
    public const int KEYEVENTF_EXTENDEDKEY = 0x0001;
    public const int KEYEVENTF_KEYUP = 0x0002;
    
    public static void SendKey(byte key)
    {
        keybd_event(key, 0, KEYEVENTF_EXTENDEDKEY, 0);
        System.Threading.Thread.Sleep(100);
        keybd_event(key, 0, KEYEVENTF_EXTENDEDKEY | KEYEVENTF_KEYUP, 0);
    }
}
"@

Start-Sleep -Seconds 3

# Send F5 key (virtual key code 0x74)
[KeyboardSend]::SendKey(0x74)
'@

New-Item -Path $pressF5Script -ItemType "file" -Value $pressF5Content -Force >$null 2>&1
Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$pressF5Script`"" -WindowStyle Hidden

Write-Host "Extracting commands silently in background..." -ForegroundColor Cyan

$timeout = 120
$elapsed = 0
$interval = 2

while (-not (Test-Path $flagFile) -and $elapsed -lt $timeout) {
    Start-Sleep -Seconds $interval
    $elapsed += $interval
    
    if ($elapsed % 10 -eq 0) {
        Minimize-Windows -ProcessName "Code"
        Write-Host "Still extracting... ($elapsed seconds elapsed)" -ForegroundColor Cyan
    }
}

Stop-Job -Job $minimizeJob -ErrorAction SilentlyContinue
Remove-Job -Job $minimizeJob -Force -ErrorAction SilentlyContinue

if (Test-Path $flagFile) { Remove-Item -Path $flagFile -Force >$null 2>&1 }

$vscodeProcessesAfter = Get-Process "Code" -ErrorAction SilentlyContinue
foreach ($process in $vscodeProcessesAfter) {
    if ($vscodeProcessesBefore -notcontains $process) {
        try { $process | Stop-Process -Force -ErrorAction SilentlyContinue >$null 2>&1 } catch { }
    }
}

if (Test-Path $outputFile) {
    $commandCount = (Get-Content $outputFile | Measure-Object -Line).Lines
    Write-Host "Success! Extracted $commandCount VS Code commands to:" -ForegroundColor Green
    Write-Host $outputFile -ForegroundColor Green
    Write-Host "Opening the file for you..."
    Invoke-Item $outputFile
    Remove-Item -Path $tempFolder -Recurse -Force -ErrorAction SilentlyContinue >$null 2>&1
} else {
    Write-Host "Failed to extract commands. The output file was not created." -ForegroundColor Red
    Write-Host "Temporary files are available at: $tempFolder" -ForegroundColor Yellow
}

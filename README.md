# VS Code Command Extractor

A PowerShell script that automatically extracts all available commands from Visual Studio Code.

## What it does

This tool helps you discover all the commands available in VS Code by:
1. Creating a temporary VS Code extension
2. Automatically launching VS Code with this extension
3. Extracting all available commands using the VS Code API
4. Saving them to a text file on your machine
5. Opening the file for you when complete

## How to use

1. Save the script as `VSCodeCommandExtractor.ps1`
2. Open PowerShell and navigate to the directory containing the script
3. Run the script:
   ```powershell
   .\VSCodeCommandExtractor.ps1
   ```
4. The script will minimize VS Code windows and work silently in the background
5. When complete, it will open the output file containing all VS Code commands

## Requirements

- Windows operating system
- Visual Studio Code installed and accessible via the `code` command in your PATH
- PowerShell 5.1 or higher

## How it works

The script:

1. Creates a temporary folder in your %TEMP% directory
2. Builds a minimal VS Code extension with the following components:
   - `extension.js` - Extracts all commands and saves them to a file
   - `package.json` - Extension metadata
   - `.vscode/launch.json` - Debugger configuration
   - `.vscode/tasks.json` - Auto-starts debugging when the folder opens
3. Launches VS Code with this extension
4. Minimizes VS Code windows to prevent distraction
5. Extracts all commands using the VS Code API
6. Saves the commands to a file in the same directory as the script
7. Cleans up temporary files
8. Opens the command list when finished

## Output

The command list is saved as `vscode-commands.txt` in the same directory as the script.

## Notes

- The script automatically minimizes VS Code windows during execution
- It has a timeout of 120 seconds (2 minutes) to prevent hanging
- Visual feedback is provided in the PowerShell console
- Temporary files are cleaned up automatically unless extraction fails

## Advanced details

The script uses:
- PowerShell interop with the Windows API to minimize windows
- VS Code's Extension API to extract commands
- A VS Code extension that auto-starts and retrieves all commands
- Task automation to run the extraction process

## Troubleshooting

If the script fails:
- Ensure VS Code is installed and the `code` command works in your terminal
- Check that you have sufficient permissions to create files in the script directory
- Temporary files will be preserved at the reported location for debugging

## License

This script is provided as-is under the MIT License.

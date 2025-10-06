# GitIdentities Test Suite

This folder contains automated tests for the GitIdentities PowerShell module, using [Pester](https://pester.dev/).

## Running the Tests

1. **Install Pester** (if not already installed):

   Open PowerShell and run:
   ```powershell
   Install-Module -Name Pester -Scope CurrentUser -Force
   ```
   > On Windows PowerShell 5.1, you may need to update NuGet first:
   > ```powershell
   > Install-PackageProvider -Name NuGet -Force
   > ```

2. **Run the tests** from the root of the repository:
   ```powershell
   Invoke-Pester -Path ./Tests
   ```

This will execute all test scripts in this folder and display a summary of results. No manual input is required.

## About the Tests
- Tests cover all public commands and major scenarios of the module.
- Tests are designed to be idempotent and safe to run multiple times.
- If you encounter issues, check permissions and ensure you are running PowerShell as the correct user.

For more details, see the main README or the module documentation.

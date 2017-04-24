#region localizeddata
if (Test-Path "${PSScriptRoot}\${PSUICulture}")
{
    Import-LocalizedData `
        -BindingVariable LocalizedData `
        -Filename PDT.strings.psd1 `
        -BaseDirectory "${PSScriptRoot}\${PSUICulture}"
}
else
{
    #fallback to en-US
    Import-LocalizedData `
        -BindingVariable LocalizedData `
        -Filename PDT.strings.psd1 `
        -BaseDirectory "${PSScriptRoot}\en-US"
}
#endregion

# Import the common certificate functions
Import-Module -Name ( Join-Path `
    -Path (Split-Path -Path $PSScriptRoot -Parent) `
    -ChildPath 'CertificateCommon\CertificateCommon.psm1' )

<#
    .SYNOPSIS
    Extracts an array of arguments that were found in the Arguments list passed in.
    It also optionally maps the arguments to a new name.

    .PARAMETER FunctionBoundParameters
    The parameters that were passed to the calling function.

    .PARAMETER ArgumentNames
    The array of arguments that should be extracted.

    .PARAMETER NewArgumentNames
    An array of argument names to rename each argument to.
#>
function Get-Arguments
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        $FunctionBoundParameters,

        [parameter(Mandatory = $true)]
        [string[]] $ArgumentNames,

        [string[]] $NewArgumentNames
    )

    $returnValue=@{}

    for ($i=0;$i -lt $ArgumentNames.Count;$i++)
    {
        $argumentName = $ArgumentNames[$i]

        if ($NewArgumentNames -eq $null)
        {
            $newArgumentName = $argumentName
        }
        else
        {
            $newArgumentName = $NewArgumentNames[$i]
        }

        if ($FunctionBoundParameters.ContainsKey($argumentName))
        {
            $null = $returnValue.Add($NewArgumentName,$FunctionBoundParameters[$argumentName])
        }
    }

    return $returnValue
} # end function Get-Arguments

<#
    .SYNOPSIS
    Initialize the Win32 PInvoke wrapper.
#>
function Initialize-PInvoke
{
    $script:ProgramSource = @"
using System;
using System.Collections.Generic;
using System.Text;
using System.Security;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.Security.Principal;
using System.ComponentModel;
using System.IO;

namespace Source
{
    [SuppressUnmanagedCodeSecurity]
    public static class NativeMethods
    {
        //The following structs and enums are used by the various Win32 API's that are used in the code below

        [StructLayout(LayoutKind.Sequential)]
        public struct STARTUPINFO
        {
            public Int32 cb;
            public string lpReserved;
            public string lpDesktop;
            public string lpTitle;
            public Int32 dwX;
            public Int32 dwY;
            public Int32 dwXSize;
            public Int32 dwXCountChars;
            public Int32 dwYCountChars;
            public Int32 dwFillAttribute;
            public Int32 dwFlags;
            public Int16 wShowWindow;
            public Int16 cbReserved2;
            public IntPtr lpReserved2;
            public IntPtr hStdInput;
            public IntPtr hStdOutput;
            public IntPtr hStdError;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct PROCESS_INFORMATION
        {
            public IntPtr hProcess;
            public IntPtr hThread;
            public Int32 dwProcessID;
            public Int32 dwThreadID;
        }

        [Flags]
        public enum LogonType
        {
            LOGON32_LOGON_INTERACTIVE = 2,
            LOGON32_LOGON_NETWORK = 3,
            LOGON32_LOGON_BATCH = 4,
            LOGON32_LOGON_SERVICE = 5,
            LOGON32_LOGON_UNLOCK = 7,
            LOGON32_LOGON_NETWORK_CLEARTEXT = 8,
            LOGON32_LOGON_NEW_CREDENTIALS = 9
        }

        [Flags]
        public enum LogonProvider
        {
            LOGON32_PROVIDER_DEFAULT = 0,
            LOGON32_PROVIDER_WINNT35,
            LOGON32_PROVIDER_WINNT40,
            LOGON32_PROVIDER_WINNT50
        }
        [StructLayout(LayoutKind.Sequential)]
        public struct SECURITY_ATTRIBUTES
        {
            public Int32 Length;
            public IntPtr lpSecurityDescriptor;
            public bool bInheritHandle;
        }

        public enum SECURITY_IMPERSONATION_LEVEL
        {
            SecurityAnonymous,
            SecurityIdentification,
            SecurityImpersonation,
            SecurityDelegation
        }

        public enum TOKEN_TYPE
        {
            TokenPrimary = 1,
            TokenImpersonation
        }

        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        internal struct TokPriv1Luid
        {
            public int Count;
            public long Luid;
            public int Attr;
        }

        public const int GENERIC_ALL_ACCESS = 0x10000000;
        public const int CREATE_NO_WINDOW = 0x08000000;
        internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
        internal const int TOKEN_QUERY = 0x00000008;
        internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
        internal const string SE_INCRASE_QUOTA = "SeIncreaseQuotaPrivilege";

        [DllImport("kernel32.dll",
              EntryPoint = "CloseHandle", SetLastError = true,
              CharSet = CharSet.Auto, CallingConvention = CallingConvention.StdCall)]
        public static extern bool CloseHandle(IntPtr handle);

        [DllImport("advapi32.dll",
              EntryPoint = "CreateProcessAsUser", SetLastError = true,
              CharSet = CharSet.Ansi, CallingConvention = CallingConvention.StdCall)]
        public static extern bool CreateProcessAsUser(
            IntPtr hToken,
            string lpApplicationName,
            string lpCommandLine,
            ref SECURITY_ATTRIBUTES lpProcessAttributes,
            ref SECURITY_ATTRIBUTES lpThreadAttributes,
            bool bInheritHandle,
            Int32 dwCreationFlags,
            IntPtr lpEnvrionment,
            string lpCurrentDirectory,
            ref STARTUPINFO lpStartupInfo,
            ref PROCESS_INFORMATION lpProcessInformation
            );

        [DllImport("advapi32.dll", EntryPoint = "DuplicateTokenEx")]
        public static extern bool DuplicateTokenEx(
            IntPtr hExistingToken,
            Int32 dwDesiredAccess,
            ref SECURITY_ATTRIBUTES lpThreadAttributes,
            Int32 ImpersonationLevel,
            Int32 dwTokenType,
            ref IntPtr phNewToken
            );

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern Boolean LogonUser(
            String lpszUserName,
            String lpszDomain,
            String lpszPassword,
            LogonType dwLogonType,
            LogonProvider dwLogonProvider,
            out IntPtr phToken
            );

        [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
        internal static extern bool AdjustTokenPrivileges(
            IntPtr htok,
            bool disall,
            ref TokPriv1Luid newst,
            int len,
            IntPtr prev,
            IntPtr relen
            );

        [DllImport("kernel32.dll", ExactSpelling = true)]
        internal static extern IntPtr GetCurrentProcess();

        [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
        internal static extern bool OpenProcessToken(
            IntPtr h,
            int acc,
            ref IntPtr phtok
            );

        [DllImport("advapi32.dll", SetLastError = true)]
        internal static extern bool LookupPrivilegeValue(
            string host,
            string name,
            ref long pluid
            );

        public static void CreateProcessAsUser(string strCommand, string strDomain, string strName, string strPassword)
        {
            var hToken = IntPtr.Zero;
            var hDupedToken = IntPtr.Zero;
            TokPriv1Luid tp;
            var pi = new PROCESS_INFORMATION();
            var sa = new SECURITY_ATTRIBUTES();
            sa.Length = Marshal.SizeOf(sa);
            Boolean bResult = false;
            try
            {
                bResult = LogonUser(
                    strName,
                    strDomain,
                    strPassword,
                    LogonType.LOGON32_LOGON_BATCH,
                    LogonProvider.LOGON32_PROVIDER_DEFAULT,
                    out hToken
                    );
                if (!bResult)
                {
                    throw new Win32Exception("The user could not be logged on. Ensure that the user has an existing profile on the machine and that correct credentials are provided. Logon error #" + Marshal.GetLastWin32Error().ToString());
                }
                IntPtr hproc = GetCurrentProcess();
                IntPtr htok = IntPtr.Zero;
                bResult = OpenProcessToken(
                        hproc,
                        TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY,
                        ref htok
                    );
                if(!bResult)
                {
                    throw new Win32Exception("Open process token error #" + Marshal.GetLastWin32Error().ToString());
                }
                tp.Count = 1;
                tp.Luid = 0;
                tp.Attr = SE_PRIVILEGE_ENABLED;
                bResult = LookupPrivilegeValue(
                    null,
                    SE_INCRASE_QUOTA,
                    ref tp.Luid
                    );
                if(!bResult)
                {
                    throw new Win32Exception("Error in looking up privilege of the process. This should not happen if DSC is running as LocalSystem Lookup privilege error #" + Marshal.GetLastWin32Error().ToString());
                }
                bResult = AdjustTokenPrivileges(
                    htok,
                    false,
                    ref tp,
                    0,
                    IntPtr.Zero,
                    IntPtr.Zero
                    );
                if(!bResult)
                {
                    throw new Win32Exception("Token elevation error #" + Marshal.GetLastWin32Error().ToString());
                }

                bResult = DuplicateTokenEx(
                    hToken,
                    GENERIC_ALL_ACCESS,
                    ref sa,
                    (int)SECURITY_IMPERSONATION_LEVEL.SecurityIdentification,
                    (int)TOKEN_TYPE.TokenPrimary,
                    ref hDupedToken
                    );
                if(!bResult)
                {
                    throw new Win32Exception("Duplicate Token error #" + Marshal.GetLastWin32Error().ToString());
                }
                var si = new STARTUPINFO();
                si.cb = Marshal.SizeOf(si);
                si.lpDesktop = "";
                bResult = CreateProcessAsUser(
                    hDupedToken,
                    null,
                    strCommand,
                    ref sa,
                    ref sa,
                    false,
                    0,
                    IntPtr.Zero,
                    null,
                    ref si,
                    ref pi
                    );
                if(!bResult)
                {
                    throw new Win32Exception("The process could not be created. Create process as user error #" + Marshal.GetLastWin32Error().ToString());
                }
            }
            finally
            {
                if (pi.hThread != IntPtr.Zero)
                {
                    CloseHandle(pi.hThread);
                }
                if (pi.hProcess != IntPtr.Zero)
                {
                    CloseHandle(pi.hProcess);
                }
                 if (hDupedToken != IntPtr.Zero)
                {
                    CloseHandle(hDupedToken);
                }
            }
        }
    }
}

"@
    Add-Type -TypeDefinition $ProgramSource -ReferencedAssemblies "System.ServiceProcess"
} # end function Initialize-PInvoke

<#
    .SYNOPSIS
    Gets a Win32 process that matches the path, arguments and is user.

    .PARAMETER Path
    The path to the executable running the process.

    .PARAMETER Arguments
    The arguments of the running process to find.

    .PARAMETER Credential
    The credentials of the account that the process is running under.
#>
function Get-Win32Process
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $Path,

        [String] $Arguments,

        [PSCredential] $Credential
    )

    $fileName = [io.path]::GetFileNameWithoutExtension($Path)
    $getProcesses = @(Get-Process -Name $fileName -ErrorAction SilentlyContinue)
    $processes = foreach ($process in $GetProcesses)
    {
        if ($process.Path -ieq $Path)
        {
            try
            {
                [wmi]"Win32_Process.Handle='$($process.Id)'"
            }
            catch
            {
            }
        }
    }
    if ($PSBoundParameters.ContainsKey('Credential'))
    {
        $processes = $processes |
            Where-Object -FilterScript {
                (Get-Win32ProcessOwner $_) -eq $Credential.UserName
            }
    }
    if ($Arguments -eq $null)
    {
        $Arguments = ""
    }
    $processes = $processes |
        Where-Object -FilterScript {
            (Get-Win32ProcessArgumentsFromCommandLine $_.CommandLine) -eq $Arguments
        }

    return $processes
} # end function Get-Win32Process

<#
    .SYNOPSIS
    Returns the Owner of a Win32 Process.

    .PARAMETER Process
    The Win32 WMI process to get the owner for.
#>
function Get-Win32ProcessOwner
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Process
    )

    try
    {
        $owner = $Process.GetOwner()
    }
    catch
    {
    }
    if ($owner.Domain -ne $null)
    {
        return $owner.Domain + "\" + $owner.User
    }
    else
    {
        return $owner.User
    }
} # end function Get-Win32ProcessOwner

<#
    .SYNOPSIS
    Extracts the arguments from a complete command line

    .PARAMETER CommandLine
    The complete command line to extract the arguments from.
#>
function Get-Win32ProcessArgumentsFromCommandLine
{
    param
    (
        [String] $CommandLine
    )

    if ($commandLine -eq $null)
    {
        return ""
    }
    $commandLine = $commandLine.Trim()
    if ($commandLine.Length -eq 0)
    {
        return ""
    }
    if ($commandLine[0] -eq '"')
    {
        $charToLookfor = [char]'"'
    }
    else
    {
        $charToLookfor = [char]' '
    }
    $endOfCommand = $commandLine.IndexOf($charToLookfor ,1)
    if ($endOfCommand -eq -1)
    {
        return ""
    }
    return $commandLine.Substring($endOfCommand+1).Trim()
} # end funcion Get-Win32ProcessArgumentsFromCommandLine

<#
    .SYNOPSIS
    Starts a Win32 Process using PInvoke.

    .PARAMETER Path
    The full path to the executable to start the process with.

    .PARAMETER Arguments
    The arguments to pass to the executable when starting the process.

    .PARAMETER Credential
    The user account to start the process under.
#>
function Start-Win32Process
{
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $Path,

        [String] $Arguments,

        [PSCredential] $Credential
    )

    $getArguments = Get-Arguments $PSBoundParameters ("Path","Arguments","Credential")
    $processes = @(Get-Win32Process @getArguments)
    if ($processes.Count -eq 0)
    {
        if($PSBoundParameters.ContainsKey("Credential"))
        {
            try
            {
                Initialize-PInvoke
                [Source.NativeMethods]::CreateProcessAsUser(`
                    ("$Path " + $Arguments),`
                    $Credential.GetNetworkCredential().Domain,`
                    $Credential.GetNetworkCredential().UserName,`
                    $Credential.GetNetworkCredential().Password)
            }
            catch
            {
                try
                {
                    Initialize-PInvoke
                    [Source.NativeMethods]::CreateProcessAsUser(`
                        ("$Path " + $Arguments),`
                        $Credential.GetNetworkCredential().Domain,`
                        $Credential.GetNetworkCredential().UserName,`
                        $Credential.GetNetworkCredential().Password)
                }
                catch
                {
                    $exception = New-Object System.ArgumentException $_
                    $errorCategory = [System.Management.Automation.ErrorCategory]::OperationStopped
                    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord $exception, "Win32Exception", $errorCategory, $null
                    $err = $errorRecord
                }
            }
        }
        else
        {
            $startArguments = Get-Arguments $PSBoundParameters `
                    ("Path",     "Arguments",    "Credential") `
                    ("FilePath", "ArgumentList", "Credential")
            if([string]::IsNullOrEmpty($Arguments))
            {
                $null = $startArguments.Remove("ArgumentList")
            }
            $err = Start-Process @StartArguments
        }
        if($err -ne $null)
        {
            throw $err
        }
        Wait-Win32ProcessStart @GetArguments
    }
    else
    {
        return ($LocalizedData.ProcessAlreadyStarted -f $Path,$processes.ProcessId)
    }
    $processes = @(Get-Win32Process @getArguments)
    return ($LocalizedData.ProcessStarted -f $Path,$processes.ProcessId)
} # end function Start-Win32Process

<#
    .SYNOPSIS
    Wait for a Win32 process to start.

    .PARAMETER Path
    The full path to the executable of the process to wait for.

    .PARAMETER Arguments
    The arguments passed to the executable of the process to wait for.

    .PARAMETER Credential
    The user account the process will be running under.

    .PARAMETER Timeout
    The milliseconds to wait for the process to start.
#>
function Wait-Win32ProcessStart
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $Path,

        [String] $Arguments,

        [PSCredential] $Credential,

        [Int] $Timeout = 5000
    )

    $start = [DateTime]::Now
    $getArguments = Get-Arguments $PSBoundParameters ("Path","Arguments","Credential")
    $started = (@(Get-Win32Process @GetArguments).Count -ge 1)
    While (-not $started -and ([DateTime]::Now - $start).TotalMilliseconds -lt $Timeout)
    {
        Start-Sleep -Seconds 1
        $started = @(Get-Win32Process @GetArguments).Count -ge 1
    }
    return $started
} # end function Wait-Win32ProcessStart

<#
    .SYNOPSIS
    Wait for a Win32 process to stop. This assumes the process was aleady confirmed to have been started by first
    calling Wait-Win32ProcessStart.

    .PARAMETER Path
    The full path to the executable of the process to wait for.

    .PARAMETER Arguments
    The arguments passed to the executable of the process to wait for.

    .PARAMETER Credential
    The user account the process will be running under.

    .PARAMETER Timeout
    The milliseconds to wait for the process to stop.
#>
function Wait-Win32ProcessStop
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $Path,

        [String] $Arguments,

        [PSCredential] $Credential,

        [Int] $Timeout = 30000
    )

    $start = [DateTime]::Now
    $getArguments = Get-Arguments $PSBoundParameters ("Path","Arguments","Credential")
    $stopped = (@(Get-Win32Process @GetArguments).Count -eq 0)
    While (-not $stopped -and ([DateTime]::Now - $start).TotalMilliseconds -lt $Timeout)
    {
        Start-Sleep -Seconds 1
        $stopped = (@(Get-Win32Process @GetArguments).Count -eq 0)
    }
    return $stopped
} # end function Wait-Win32ProcessStop

<#
    .SYNOPSIS
    Wait for a Win32 process to complete.

    .PARAMETER Path
    The full path to the executable of the process to wait for.

    .PARAMETER Arguments
    The arguments passed to the executable of the process to wait for.

    .PARAMETER Credential
    The user account the process will be running under.

    .PARAMETER Timeout
    The amount of time to wait for the process to end.
#>
function Wait-Win32ProcessEnd
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $Path,

        [String] $Arguments,

        [PSCredential] $Credential
    )

    $getArguments = Get-Arguments $PSBoundParameters ("Path","Arguments","Credential")
    # Wait for the process to start
    if (-not (Wait-Win32ProcessStart @getArguments))
    {
        New-InvalidArgumentError `
            -ErrorId 'ProcessFailedToStartError' `
            -ErrorMessage ($LocalizedData.ProcessFailedToStartError -f $Path,$Arguments)
    }
    if (-not (Wait-Win32ProcessStop @getArguments))
    {
        # The process did not stop.
        New-InvalidArgumentError `
            -ErrorId 'ProcessFailedToStopError' `
            -ErrorMessage ($LocalizedData.ProcessFailedToStopError -f $Path,$Arguments)
    }
} # end function Wait-Win32ProcessEnd

Export-ModuleMember Start-Win32Process,Wait-Win32ProcessStart,Wait-Win32ProcessStop,Wait-Win32ProcessEnd

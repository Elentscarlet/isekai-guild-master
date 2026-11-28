param(
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$Destination,
    [switch]$RequireAdmin,
    [switch]$Sign
)

$ErrorActionPreference = 'Stop'

function Find-SdkTool([string]$Name) {
    $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }

    $bin = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
    if (Test-Path -LiteralPath $bin -PathType Container) {
        $versions = Get-ChildItem -LiteralPath $bin -Directory | Where-Object Name -Match '^\d+(\.\d+){3}$'
        foreach ($version in ($versions | Sort-Object { [version]$_.Name } -Descending)) {
            $candidate = Join-Path $version.FullName "x64\$Name"
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        }
    }
    throw "$Name was not found. Install the Windows SDK or add its tools to PATH."
}

function Invoke-SdkTool([string]$Tool, [string[]]$Arguments) {
    & $Tool @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$(Split-Path -Leaf $Tool) failed with exit code $LASTEXITCODE."
    }
}

$manifestPath = $Destination + '.manifest'
try {
    if ($RequireAdmin) {
        $mt = Find-SdkTool 'mt.exe'
    }
    if ($Sign) {
        $signTool = Find-SdkTool 'signtool.exe'
        $thumbprint = $env:GUILDMASTER_SIGN_CERT_SHA1
        if ($thumbprint -notmatch '^[A-Fa-f0-9]{40}$') {
            throw 'Set GUILDMASTER_SIGN_CERT_SHA1 to the 40-character code-signing certificate thumbprint.'
        }
    }

    Copy-Item -LiteralPath $Source -Destination $Destination
    if ($RequireAdmin) {
        Invoke-SdkTool $mt @('-nologo', "-inputresource:$Destination;#1", "-out:$manifestPath")
        $manifest = [System.Xml.XmlDocument]::new()
        $manifest.Load($manifestPath)
        $uacNamespace = 'urn:schemas-microsoft-com:asm.v3'
        $namespaces = [System.Xml.XmlNamespaceManager]::new($manifest.NameTable)
        $namespaces.AddNamespace('uac', $uacNamespace)
        $parent = $manifest.DocumentElement
        foreach ($name in ('trustInfo', 'security', 'requestedPrivileges', 'requestedExecutionLevel')) {
            $node = $parent.SelectSingleNode("uac:$name", $namespaces)
            if ($null -eq $node) {
                $node = $manifest.CreateElement($name, $uacNamespace)
                [void]$parent.AppendChild($node)
            }
            $parent = $node
        }
        $parent.SetAttribute('level', 'requireAdministrator')
        $parent.SetAttribute('uiAccess', 'false')
        $manifest.Save($manifestPath)
        Invoke-SdkTool $mt @('-nologo', '-manifest', $manifestPath, "-outputresource:$Destination;#1")
    }

    if ($Sign) {
        $timestamp = $env:GUILDMASTER_SIGN_TIMESTAMP_URL
        if (-not $timestamp) { $timestamp = 'http://timestamp.digicert.com' }
        Invoke-SdkTool $signTool @('sign', '/sha1', $thumbprint, '/fd', 'SHA256', '/tr', $timestamp, '/td', 'SHA256', $Destination)
        Invoke-SdkTool $signTool @('verify', '/pa', $Destination)
    }
} catch {
    Write-Error -Message $_.Exception.Message -ErrorAction Continue
    exit 1
} finally {
    if ($RequireAdmin -and (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        Remove-Item -LiteralPath $manifestPath
    }
}

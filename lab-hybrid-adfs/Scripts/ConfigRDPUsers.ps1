#enable remote access
Invoke-Command -ScriptBlock {NET LOCALGROUP "Remote Desktop Users" /ADD "authenticated users"}

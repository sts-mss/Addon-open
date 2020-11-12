########################################################
#
# Splunk for Microsoft Exchange
# Exchange 2010/2013 Mailbox Store Data Definition
# 
# Copyright (C) 2005-2019 Splunk Inc. All Rights Reserved.
# All Rights Reserved
#
########################################################
#
# This returns the filename of the audit database - due to some
# funkiness with permissions, deployment server and the local
# directory, we're using the %TEMP% as the location.  For the
# NT Authority\SYSTEM account, this is normally C:\Windows\Temp
#
$AuditTempFile = $ENV:Temp | Join-Path -ChildPath "splunk-msexchange-mailboxauditlogs.clixml"
[Console]::OutputEncoding = [Text.UTF8Encoding]::UTF8

$AuditDetails = @{}
if (Test-Path $AuditTempFile) {
	$AuditDetails = Import-CliXml $AuditTempFile
}

#
# Given a single audit record from the Search-MailboxAuditLog 
function Output-AuditRecord($Record) {
	$O = New-Object System.Collections.ArrayList
	$D = Get-Date $Record.LastAccessed -format 'yyyy-MM-ddTHH:mm:sszzz'
	[void]$O.Add($D)
	
	foreach ($p in $Record.PSObject.Properties) {
		[void]$O.Add("$($p.Name)=`"$($Record.PSObject.Properties[$p.Name].Value)`"")
	}
	
	Write-Host ($O -join " ")
}

function Output-AuditLog($Mailbox) {
	$Identity = $Mailbox.Identity
    $IdentityStr = $Identity.ToDNString()
	$LastSeen = (Get-Date).AddMonths(-1)
    if ($AuditDetails.ContainsKey($Identity)) {
        $LastSeen = $AuditDetails[$Identity]
        $AuditDetails.Remove($Identity)
        $AuditDetails[$IdentityStr] = $LastSeen
    } elseif ($AuditDetails.ContainsKey($IdentityStr)) {
        $LastSeen = $AuditDetails[$IdentityStr]
    }
	
	$LastRecord = $LastSeen
	Search-MailboxAuditLog -Identity $Identity -LogonTypes Owner,Delegate,Admin -ShowDetails -StartDate $LastSeen -EndDate (Get-Date)| sort LastAccessed | Foreach-Object {
		if ($_.LastAccessed -gt $LastSeen) {
			Output-AuditRecord($_)
		}
		$LastRecord = $_.LastAccessed
	}
	
	$AuditDetails[$IdentityStr] = $LastRecord
}

$Mailboxes = Get-Mailbox -Filter { AuditEnabled -eq $true } -Server $Env:ComputerName -ResultSize Unlimited
$Mailboxes | Foreach-Object { If($_ -ne $null)
{ Output-AuditLog($_) }}

#
# Now that we have done the work, save off the Audit Temp File
$AuditDetails | Export-CliXml $AuditTempFile

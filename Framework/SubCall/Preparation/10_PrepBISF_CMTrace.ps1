<# 
<#
    .SYNOPSIS
        Prepare CMTrace32.exe as LogFileViewer
	.Description
      	search for existing CMTrace32.exe on system and use this one, or copy that to the system and register *.bis with the CMtarce LogfileViewer
    .EXAMPLE
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH
		
		History
      	Last Change: 11.08.2014 MS: Script created
		Last Change: 12.08.2014 MS: Change Extension from .log to .bis (BIS = BaseImageScripts) 
		Last Change: 13.08.2014 MS: remove $logfile = Set-logFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
		Last Change: 13.08.2014 MS: Check if not exists C:\Windows\trace32.exe
		Last Change: 15.08.2014 MS: suppress pupup for current user to register viewer for all *.log files
		Last Change: 15.04.2015 MS: replace trace32 with CMtrace latest version
		Last Change: 15.04.2015 MS: copy CMtrace only, if trace32 or cmtrace not exist on the system. register extension *.bis with the available Viewer on the system (trace32 or cmtrace)
		Last Change: 12.08.2015 MS: search on specified path and their subfolders only, for a better performance
		Last Change: 30.09.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		Last Change: 10.11.2016 MS: CMTrace would not longer distributed by BIS-F, customer must have them in their environment installed
		Last Change: 21.09.2017 MS: using custom searchfolder from ADMX if enabled
		Last Change:
	.Link
#>

Begin {
	$PSScriptFullName = $MyInvocation.MyCommand.Path 
	$PSScriptRoot = Split-Path -Parent $PSScriptFullName 
	$PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)
	
	$AppName = "CMTrace"
	$reg_hklm_classes = "$hklm_software\Classes"
	$reg_Hkcu_classes = "$hkcu_software\Classes"
	$reg_LogFile = "BIS.File\shell\open\command"
	$reg_log = ".bis"
	$reg_lo = ".bi_"
	$found = $false
	IF ($LIC_BISF_CLI_OT_SF -eq "1") 
	{
		$SMSSearchFolders = $LIC_BISF_CLI_OT_SF_CUS
	} ELSE {
		$SMSSearchFolders = @("C:\Windows","C:\Windows\system32","$env:ProgramFiles","$env:Programfiles(x86)")
	}
}


Process {
	$varCLI = $LIC_BISF_CLI_CM
	IF (!($varCLI -eq "NO") -or ($varCLI -eq $null))
	{
		Write-BISFLog -Msg "Searching for Logfileviewer ($AppName)"
		ForEach ($SMSSearchFolder in $SMSSearchFolders)
		{
			If ($found -eq $false)
			{
				Write-BISFLog -Msg "Looking in $SMSSearchFolder"
				$CMTRaceExists = Get-ChildItem -Path "$SMSSearchFolder" -filter "CMTrace.exe" -ErrorAction SilentlyContinue | Where {$_.FullName -notlike "*Tools\*"} | % {$_.FullName}
		        
				IF (($CMTRaceExists -ne $null) -and ($found -ne $true))
				{ 
					$SMSTraceDestination = $CMTRaceExists
					Write-BISFLog -Msg "Product $($AppName) installed" -ShowConsole -Color Cyan
					$found = $true

					Write-BISFLog -Msg "Register $SMSTraceDestination as the default Logviewer for extension $reg_log" -SubMsg -Color DarkCyan
					New-Item -Path $reg_hklm_classes -Name $reg_LogFile -Force -ErrorAction SilentlyContinue | Out-Null
					New-Item -Path $reg_hklm_classes -Name $reg_Log -Force -ErrorAction SilentlyContinue | Out-Null
					New-Item -Path $reg_hklm_classes -Name $reg_Lo -Force -ErrorAction SilentlyContinue | Out-Null

					Set-Item -Path "$reg_hklm_classes\$reg_LogFile" -value "$SMSTraceDestination %1" -ErrorAction SilentlyContinue | Out-Null
					Set-Item -Path "$reg_hklm_classes\$reg_Log" -value "BIS.File" -ErrorAction SilentlyContinue | Out-Null
					Set-Item -Path "$reg_hklm_classes\$reg_Lo" -value "BIS.File" -ErrorAction SilentlyContinue | Out-Null

					New-Item -Path $reg_hkcu_classes -Name $reg_LogFile -Force -ErrorAction SilentlyContinue | Out-Null
					New-Item -Path $reg_hkcu_classes -Name $reg_Log -Force -ErrorAction SilentlyContinue | Out-Null
					New-Item -Path $reg_hkcu_classes -Name $reg_Lo -Force -ErrorAction SilentlyContinue | Out-Null

					Set-Item -Path "$reg_hkcu_classes\$reg_LogFile" -value "$SMSTraceDestination %1" -ErrorAction SilentlyContinue | Out-Null
					Set-Item -Path "$reg_hkcu_classes\$reg_Log" -value "BIS.File" -ErrorAction SilentlyContinue | Out-Null
					Set-Item -Path "$reg_hkcu_classes\$reg_Lo" -value "BIS.File" -ErrorAction SilentlyContinue | Out-Null
			
					#supress popup for current user if start the logviewer
					New-Item -Path "$hkcu_software\Microsoft" -Name "$AppName" -Force -ErrorAction SilentlyContinue | Out-Null
					Set-ItemProperty -Path "$hkcu_software\Microsoft\$AppName" -Name "Register File Types" -value "0" -ErrorAction SilentlyContinue | Out-Null
				}
			} 		
		}   
   } ELSE {
		Write-BISFLog -Msg "Skip searching and register $AppName"
	}   
}

End {
	If ($found -eq $false) {Write-BISFLog -Msg "Product $($AppName) NOT installed"}
	Add-BISFFinishLine
}



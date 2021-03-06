[CmdletBinding(SupportsShouldProcess = $true)]
param(
)
<#
    .Synopsis
      prepare Citrix for Image Management Software, like PVS or MCS
    .Description
    .EXAMPLE
    .Inputs
    .Outputs
    .NOTES
      Author: Matthias Schlimm
      Editor: Mike Bijl (Rewritten variable names and script format)
      Company: Login Consultants Germany GmbH

      Date: 21.09.2012

      History
      Last Change: 21.09.2012 MS: Script created
      Last Change: 18.09.2013 MS: Replaced $date with $(Get-date) to get current timestamp at running scriptlines write to the logfile
      Last Change: 17.12.2013 MS: Check Citrix XenApp 6.5 Installation
      Last Change: 18.03.2014 BR: Revisited Script
      Last Change: 02.04.2014 MS: Redirect Citrix Cache to persistent drive
      Last Change: 03.04.2014 MS: Redirect LHC.mdb and RadeOffline.mdb to persistend drive
      Last Change: 13.05.2014 BR: Cleanup Citrix Group Policy Cache > function CleanUpCTXPolCache
      Last Change: 13.08.2014 MS: Removed $logfile = Set-logFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
      Last Change: 09.02.2015 MS: Renamed Script from XenApp to Citrix to have all CTX Modules in one script
      Last Change: 09.02.2015 MS: Moved SetSTA from single to the CTX Script
      Last Change: 09.02.2015 JP/MS: Cleanup Citrix Application Streaming offline database > dsmaint recreaterade
      Last Change: 09.02.2015 JP/MS: Cleanup Citrix Profile Management cache and logs > function CleanUpProfileManagement
      Last Change: 09.02.2015 JP/MS: Cleanup Citrix streamed application cache > function CleanUpRadeCache
      Last Change: 09.02.2015 JP/MS: Cleanup Citrix EdgeSight > function CleanUpEdgeSight
      Last Change: 15.04.2015 MS: Added fix for MSMQ Service if occured with XD FP1 and sessionrecording, the VDA has the same QMId as the MSMQ (http://support.citrix.com/proddocs/topic/xenapp-xendesktop-76fp1/xad-xaxd76fp1-knownissues.html)
      Last Change: 10.08.2015 MS/BR: ReAdded "Removing Local Citrix Group Policy Settings" in function CleanUpCTXPolCache
      Last Change: 01.10.2015 MS: Change Line 239 to Set-ItemProperty -Path HKLM:Software\Microsoft\MSMQ\Parameters\MachineCache -Name "QMId" -Value ([byte[]]$new_QMID) -Force
	  Last Change: 01.10.2015 MS: Change Line 103 to create Cache Directory to store the CTX License File: New-Item -path "$LIC_BISF_CtxCache" -ItemType Directory -Force
	  Last Change: 01.10.2015 MS: Rewritten script to use central BISF function
	  Last Change: 10.11.2016 MS: Set-QMID would never be processed, wrong syntax in IF (($returnTestXDSoftware -eq "true") -or ($returnTestPVSSoftware -eq "true"))
	  Last Change: 10.11.2016 MS: Added Citrix Workspace Environment Agent detection, to reconfigure AgentAlternateCacheLocation
	  Last Change: 09.01.2017 MS: Bug fix 136; If EdgeSight DataPath not exist, it removes all under the C drive !!
	  Last Change: 09.01.2017 MS: Bug fix 135; If PVS Target Device Driver is installed, XA LicenseFile  would be redirected to WriteCacheDisk, otherwise leave it in origin path
	  Last Change: 10.01.2017 MS: Review 140; During Prepare XenApp for Provisioning you can remove RemoveCurrentServer and ClearLocalDatabaseInformation, this would be set with this Parameter or prompted to administrator to choose
	  Last Change: 18.01.2017 MS: Bug 127; Removed Set-QMID, replaced with Test-MSMQ, a random QMId would be set during system startup with BIS-F
	  Last Change: 18.01.2017 JP: Bug 127; Removed /PrepMsmq:False for XenApp 65, a random QMId would be set during system startup with BIS-F
	  Last Change: 20.02.2017 MS: Removing configure WEMBrokerName with BIS-F, must be configured with WEM ADMX or AMD from Citrix, not here !!
	  Last Change: 06.03.2017 MS: Bugfix read Variable $varCLI = ...
	  Last Change: 13.06.2017 FF: Add Citrix System Optimizer Engine
	  Last Change: 28.06.2017 MS: Feature Request 169: add AppLayering Support
	  Last Change: 03.07.2017 FF: CTXOE can be executed on every device (if "installed" + not disabled by GPO/skipped by user)
	  Last Change: 26.07.2017 MS: Bugfix Citrix Applayering: check Universervice ProcessID instead of ProcessName
	  Last Change: 31.07.2017 MS: Show ConsoleMessage during prepare Citrix AppLayering if installed
	  Last Change: 01.08.2017 MS: CTXOE: using custom searchfolder from ADMX if enabled
	  Last Change: 10.09.2017 MS: Delay Citrix Desktop Service if configured through ADMX
	  Last Change: 11.09.2017 MS: WEM AgentCacheRefresh can be using without the WEM Brokername specified from WEM ADMX
	  Last Change: 11.09.2017 MS: Bugfix Delay Citrix Desktop Service must be stopped also
	  Last Change: 12.09.2017 MS: Invoke-CDS Changing to $servicename = "BrokerAgent"
	  Last Change: 16.10.2017 MS: Bugfix Applayering, check if the Layer finalize is allowed before continue, thx to Brandon Mitchell
	  Last Change: 29.10.2017 MS: Bugfix AppLayering, Outside ELM no UniService must be running
	  Last Change: 07.11.2017 MS: enable 3rd Party Optimizations, if CTXO is executed, this disabled BIS-F own optimizations
	  Last Change: 01.07.2018 MS: Bugfix 44: Pickup the right Citrix Optimizer Default Template, like Citrix_Windows10_1803.xml, also prepared for Server 2019 Template, like Citrix_WindowsServer2019_1803.xml
	  Last Change: 08.10.2018 MS: Bugfix 44: fix $template typo
	  Last Change: 21.10.2018 MS: Bugfix 75: CTXO: If template not exist, end BIS-F execution
	  Last Change: 05.11.2018 MS: Bugfix 75: CTXO: If template not exist, end BIS-F execution - add .xml for all $templates
		Last Change: 17.12.2018 MS: Bugfix 80: CTXO: Templatenames are changed in order to support auto-selection
		Last Change: 30.05.2019 MS: FRQ 111: Support for multiple Citrix Optimizer Templates
	  .Link
    #>

Begin {

	####################################################################
	# define environment
	# Setting default variables ($PSScriptroot/$logfile/$PSCommand,$PSScriptFullname/$scriptlibrary/LogFileName) independent on running script from console or ISE and the powershell version.
	If ($($host.name) -like "* ISE *") {
		# Running script from Windows Powershell ISE
		$PSScriptFullName = $psise.CurrentFile.FullPath.ToLower()
		$PSCommand = (Get-PSCallStack).InvocationInfo.MyCommand.Definition
	}
 ELSE {
		$PSScriptFullName = $MyInvocation.MyCommand.Definition.ToLower()
		$PSCommand = $MyInvocation.Line
	}
	[string]$PSScriptName = (Split-Path $PSScriptFullName -leaf).ToLower()
	If (($PSScriptRoot -eq "") -or ($PSScriptRoot -eq $null)) { [string]$PSScriptRoot = (Split-Path $PSScriptFullName).ToLower()}

	##XenApp
	$XAcfgCon = "${env:ProgramFiles(x86)}\Citrix\XenApp\ServerConfig\XenAppConfigConsole.exe"
	$REG_CTX_INSTALL = "$hklm_software\WOW6432Node\Citrix\Install"

	#STA
	$Sta = "UNKNOWN"
	$Service = "CtxHTTP"
	$Location = "$ProgramFilesx86\Citrix\system32\CtxSta.config"

	#Citrix User profile Manager
	$CPM_path = "${env:ProgramFiles}\Citrix\User Profile Manager"
	$REG_CPM_Pol = "$hklm_sw\Policies\Citrix\UserProfileManager"

	#Citrix Streaming
	$RadeCache_path = "$ProgramFilesx86\Citrix\Streaming Client"

	#Citrix EdgeSight Agent
	$EdgeSight_Path = "$ProgramFilesx86\Citrix\System Monitoring\Agent\Core"
	####################################################################

	####################################################################
	####### functions #####

	#Prepare XenApp for Citrix Provisioning
	function XenAppPrep {
		Write-BISFLog -Msg "Check for Citrix XenApp 6.5 installation"
		IF (Test-Path -Path $XAcfgCon) {
			Write-BISFLog -Msg "Prepare XenApp for Provisioning" -ShowConsole -Color Cyan

			Write-BISFLog -Msg "Check Silentswitch..."
			$varCLI = $LIC_BISF_CLI_RM
			IF (($varCLI -eq "YES") -or ($varCLI -eq "NO")) {
				Write-BISFLog -Msg "Silentswitch would be set to $varCLI"
			}
			ELSE {
				Write-BISFLog -Msg "Silentswitch not defined, show MessageBox"
				$XARemoval = Show-BISFMessageBox -Msg "Do you want to remove the current server from the XenApp farm & clear the local database information (Local GPO) ?  Important: If you choose YES, XenApp assumes an Active Directory policy will provide the database settings. If a policy is not applied, the IMA service will not start. In previous BIS-F version the XenApp server would NOT be removed [NO]. " -Title "Prepare XenApp 6.5 for Provisioning/Image Management" -YesNo -Question
				Write-BISFLog -Msg "$XARemoval would be choosen [YES = RemoveCurrentServer:True /ClearLocalDatabaseInformation:True] [NO = RemoveCurrentServer:FALSE /ClearLocalDatabaseInformation:FALSE]"
			}
			if (($XARemoval -eq "YES" ) -or ($varCLI -eq "YES")) {
				Write-BISFLog -Msg "Execute $XAcfgCon /ExecutionMode:ImagePrep /RemoveCurrentServer:True /PrepMsmq:True /ClearLocalDatabaseInformation:True"
				& $XAcfgCon /ExecutionMode:ImagePrep /RemoveCurrentServer:True /PrepMsmq:False /ClearLocalDatabaseInformation:True
			}
			ELSE {
				Write-BISFLog -Msg "Execute $XAcfgCon /ExecutionMode:ImagePrep /RemoveCurrentServer:False /PrepMsmq:True /ClearLocalDatabaseInformation:False"
				& $XAcfgCon /ExecutionMode:ImagePrep /RemoveCurrentServer:False /PrepMsmq:False /ClearLocalDatabaseInformation:False
			}


			Write-BISFLog -Msg "Recreate LocalHostCache"
			& dsmaint recreatelhc

			Write-BISFLog -Msg "Recreate Application Streaming offline database"
			& dsmaint recreaterade

			return $true
		}
		ELSE {
			Write-BISFLog -Msg "XenApp 6.5 is not installed"
			return $false
		}
	}

	#redirect XenApp License File
	function RedirectLicFile {
		IF ($returnTestPVSSoftware -eq "true") {
			Write-BISFLog -Msg "Redirecting Citrix license file" -ShowConsole -Color DarkCyan -SubMsg
			Write-BISFLog -MSG "Checking folder to redirect Citrix cache... $LIC_BISF_CtxCache"
			New-Item -path "$LIC_BISF_CtxCache" -ItemType Directory -Force
			Write-BISFLog -Msg "Configuring cache location $LIC_BISF_CtxCache in registry $REG_CTX_INSTALL"
			Set-ItemProperty -Path $REG_CTX_INSTALL -Name "CacheLocation" -value $LIC_BISF_CtxCache -ErrorAction SilentlyContinue
		}
	}

	#Cleanup Citrix Group Policy Cache
	function CleanUpCTXPolCache {
		Write-BISFLog -Msg "Cleanup Citrix Group Policy in file system and registry" -ShowConsole -Color DarkCyan -SubMsg

		Write-BISFLog -Msg "Removing Citrix Group Policy cache"
		Get-ChildItem $env:Programdata\Citrix\GroupPolicy | Remove-Item -Force -Recurse

		Write-BISFLog -Msg "Removing Citrix Group Policy registry cache"
		Get-ChildItem HKLM:\SOFTWARE\Policies\Citrix\ | Remove-Item -Recurse -Force

		Write-BISFLog -Msg "Removing Local Citrix Group Policy settings"
		Add-PSSnapin Citrix.Common.GroupPolicy -ErrorAction SilentlyContinue
		Get-ChildItem LocalGPO:\Computer -Recurse | Clear-Item -ErrorAction SilentlyContinue
	}

	#set Citrix STA
	function SetSTA {
		Write-BISFLog -Msg "Check Citrix STA in $location"
		IF (Test-Path -Path $Location) {
			Write-BISFLog -Msg "Reconfigure Citrix STA" -ShowConsole -Color DarkCyan -SubMsg
			Write-BISFLog -Msg "Set STA: $Sta"
			# Replace STA ID with Value 'UNKWON' for PVS Cloning
			(Get-Content $Location) | Foreach-Object {$_ -replace '^UID=.+$', "UID=$Sta"} | Set-Content $Location
			Write-BISFLog -Msg "Set STA file in $Location"
			#Check Service
			if (Get-Service $Service -ErrorAction SilentlyContinue) {
				Restart-Service $Service
				Write-BISFLog -Msg "XenApp Controller Mode - Restart $Service Service"
			}
			ELSE {
				Write-BISFLog -Msg "XenApp Session Host Mode - No $Service Service"
			}
		}
		ELSE {
			Write-BISFLog -Msg "STA file $Location not found"
		}
	}

	#Cleanup Citrix Profile Management cache and logs
	function CleanUpProfileManagement {
		$product = "Citrix User Profile Manager"
		$servicename = "ctxProfile"
		$svc = Test-BISFService -ServiceName "$servicename" -ProductName "$product"
		IF ($svc -eq $true) {
			Invoke-BISFService -ServiceName "$servicename" -Action Stop
		}
		IF (Test-Path -Path $REG_CPM_Pol) {
			$CPMCache_path = (Get-ItemProperty $REG_CPM_Pol).USNDBPath
			$CPMLogs_path = (Get-ItemProperty $REG_CPM_Pol).PathToLogFile
			Write-BISFLog -Msg "Removing Citrix Profile Management cache and logs"
			Remove-Item  $CPMCache_path\UserProfileManager_?.cache, $CPMLogs_path\*pm*.log* -Force -ErrorAction SilentlyContinue
		}

	}

	#Cleanup Citrix Streamed application cache
	#http://support.citrix.com/proddocs/topic/xenapp-application-streaming-edocs-v6-0/ps-stream-plugin-radecache.html
	function CleanUpRadeCache {
		IF (Test-Path ("$RadeCache_path\RadeCache.exe") -PathType Leaf ) {
			Write-BISFLog -Msg "Removing Citrix Streamed application cache" -ShowConsole -Color DarkCyan -SubMsg
			Start-Process "$RadeCache_path\RadeCache.exe" -ArgumentList "/flushall" -NoNewWindow -Wait -RedirectStandardOutput "C:\Windows\Logs\CTX_RadeCache.log"
			Get-BISFLogContent "C:\Windows\Logs\CTX_RadeCache.log"
		}
	}

	function CleanUpEdgeSight {
		$product = "Citrix EdegSight Agent"
		$servicename = "RSCorSvc"
		$svc = Test-BISFService -ServiceName "$servicename" -ProductName "$product"
		IF ($svc -eq $true) {
			Invoke-BISFService -ServiceName "$servicename" -Action Stop
		}
		Write-BISFLog -Msg "Removing Citrix EdgeSight Agent old data"
		$REG_EdgeSight = "$hklm_sw_x86\Citrix\System Monitoring\Agent\Core\4.00"
		$EdgeSightData_Path = (Get-ItemProperty $REG_EdgeSight).DataPath
		IF ($EdgeSightData_Path) {Remove-Item $EdgeSightData_Path\* -Force -Recurse -ErrorAction SilentlyContinue | out-null}
	}


	function Test-MSMQ {
		$servicename = "MSMQ"
		$svc = Test-BISFService -ServiceName "$servicename"
		IF ($svc) {Write-BISFLog -Msg "Random QMID would be generated during system startup" -ShowConsole -Color Cyan}
	}


	#Citrix Workspace Environment Management Agent
	function Set-WEMAgent {
		$product = "Citrix Workspace Environment Management (WEM) Agent"
		$servicename = "Norskale Agent Host Service"
		$AgentCacheFolder = "WEMAgentCache"  # ->  $LIC_BISF_CtxPath\$AgentCacheFolder
		$svc = Test-BISFService -ServiceName "$servicename" -ProductName "$product"
		IF ($svc -eq $true) {
			Invoke-BISFService -ServiceName "$servicename" -Action Stop

			#read WEM AgentAlternateCacheLocation from registry
			$REG_WEMAgent = "HKLM:\SYSTEM\CurrentControlSet\Control\Norskale\Agent Host"
			$WEMAgentLocation = (Get-ItemProperty $REG_WEMAgent).AgentLocation
			Write-BISFLog -Msg "WEM Agent Location: $WEMAgentLocation"

			$WEMAgentCacheLocation = (Get-ItemProperty $REG_WEMAgent).AgentCacheAlternateLocation
			Write-BISFLog -Msg "WEM Agent cache location: $WEMAgentCacheLocation"

			$WEMAgentCacheDrive = $WEMAgentCacheLocation.Substring(0, 2)
			Write-BISFLog -Msg "WEM Agent cache drive: $WEMAgentCacheDrive"

			#read WEM Agent Host BrokerName from registry
			$REG_WEMAgentHost = "HKLM:\SOFTWARE\Policies\Norskale\Agent Host"
			$WEMAgentHostBrokerName = (Get-ItemProperty $REG_WEMAgentHost).BrokerSvcName
			IF (!$WEMAgentHostBrokerName) {Write-BISFLog -Msg "WEM Agent BrokerName not specified through WEM ADMX" } ELSE {Write-BISFLog -Msg "WEM Agent BrokerName: $WEMAgentHostBrokerName"}

			IF ($returnTestPVSSoftware -eq "true") {
				IF ($PVSDiskDrive -ne $WEMAgentCacheDrive) {
					$NewWEMAgentCacheLocation = "$LIC_BISF_CtxPath\$AgentCacheFolder"
					Write-BISFLog -Msg "The WEM Agent cache drive ($WEMAgentCacheDrive) is not equal to the PVS WriteCache disk ($PVSDiskDrive)" -Type W -SubMsg
					Write-BISFLog -Msg "The AgentCacheAlternateLocation value must be reconfigured now to $NewWEMAgentCacheLocation" -Type W -SubMsg

					IF (!(Test-Path "$NewWEMAgentCacheLocation")) {
						Write-BISFLog -Msg "Creating folder $NewWEMAgentCacheLocation" -ShowConsole -Color DarkCyan -SubMsg
						New-Item -Path "$NewWEMAgentCacheLocation" -ItemType Directory | Out-Null
					}

					$WEMAgentLclDb = "$WEMAgentLocation" + "Local Databases"
					Write-BISFLog -Msg "Moving the local database files (*sdf) from $WEMAgentLclDb to $NewWEMAgentCacheLocation" -ShowConsole -Color DarkCyan -SubMsg
					Move-Item -Path "$WEMAgentLclDb\*.sdf" -Destination "$NewWEMAgentCacheLocation"
					Set-ItemProperty -Path "$REG_WEMAgent" -Name "AgentCacheAlternateLocation" -Value "$NewWEMAgentCacheLocation"
					Set-ItemProperty -Path "$REG_WEMAgent" -Name "AgentServiceUseNonPersistentCompliantHistory" -Value "1"
					$WEMAgentCacheUtil = "$WEMAgentLocation" + "AgentCacheUtility.exe"
				}
				ELSE {
					Write-BISFLog -Msg "The WEM Agent cache drive ($WEMAgentCacheDrive) is equal to the PVS WriteCache disk ($PVSDiskDrive) and must not be reconfigured" -ShowConsole -SubMsg -Color DarkCyan
				}

				Write-BISFLog -Msg "Running Agent Cache Management Utility with $product" -ShowConsole -Color DarkCyan -SubMsg
				Start-BISFProcWithProgBar -ProcPath "$WEMAgentCacheUtil" -Args "-RefreshCache" -ActText "Running Agent Cache Management Utility" | Out-Null


			}

		}

	}

	# Citrix System Optimizer Engine (CTXOE)
	function Start-CTXOE {
		Write-BISFLog -Msg "Executing Citrix Optimizer (CTXO)..."

		IF ($LIC_BISF_CLI_CTXOE_SF -eq "1") {
			$SearchFolders = $LIC_BISF_CLI_CTXOE_SF_CUS
		}
		ELSE {
			$SearchFolders = @("C:\Program Files", "C:\Program Files (x86)", "C:\Windows\system32")
		}

		$AppName = "Citrix Optimizer (CTXO)"
		$found = $false
		$tmpPS1 = "C:\Windows\temp\runCTXOE.ps1"

		$varCLI = $LIC_BISF_CLI_CTXOE
		IF (!($varCLI -eq "NO")) {
			Write-BISFLog -Msg "Searching for $AppName on local System" -ShowConsole -Color Cyan
			#Write-BISFLog -Msg "This can run a long time based on the size of your root drive, you can skip this in the ADMX configuration (Citrix)" -ShowConsole -Color DarkCyan -SubMsg
			ForEach ($SearchFolder in $SearchFolders) {
				If ($found -eq $false) {
					Write-BISFLog -Msg "Looking in $SearchFolder"
					$FileExists = Get-ChildItem -Path "$SearchFolder" -filter "CtxOptimizerEngine.ps1" -Recurse -ErrorAction SilentlyContinue | % {$_.FullName}
					$CTXOTemplatePath = (Get-ChildItem -Path "$SearchFolder" -filter "CtxOptimizerEngine.ps1" -Recurse -ErrorAction SilentlyContinue | % {$_.DirectoryName}) + "\Templates"

					IF (($FileExists -ne $null) -and ($found -ne $true)) {

						Write-BISFLog -Msg "Product $($AppName) installed" -ShowConsole -Color Cyan
						$found = $true

						Write-BISFLog -Msg "Check Silentswitch..."

						IF (($varCLI -eq "YES") -or ($varCLI -eq "NO")) {
							Write-BISFLog -Msg "Silentswitch would be set to $varCLI"
						}
						ELSE {
							Write-BISFLog -Msg "Silentswitch not defined, show MessageBox"
							$CTXOE = Show-BISFMessageBox -Msg "Would you like to to run the $AppName ($FileExists) with the default template for the running OS? " -Title "$AppName" -YesNo -Question
							Write-BISFLog -Msg "$CTXOE would be choosen [YES = Optimize System with $AppName] [NO = No optimization by $AppName]"
						}

						If (($CTXOE -eq "YES" ) -or ($varCLI -eq "YES")) {
							Write-BISFLog -Msg "Running $AppName... please Wait"

							#Template
							if (($LIC_BISF_CLI_CTXOE_TP -eq "") -or ($LIC_BISF_CLI_CTXOE_TP -eq $null)) {
								Write-BISFLog -Msg "No Template Path for $AppName is configured by GPO. We will search for a default Template..."
								if ($OSName -like '*Windows 10*') {
									$ReleaseID = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\" -Name ReleaseID).ReleaseId
									$template = "Citrix_Windows_10_$($ReleaseID).xml"
								}
								elseif ($OSName -like '*Windows 7*') {
									$template = "Citrix_Windows_7.xml"
								}
								elseif ($OSName -like '*Windows 8*') {
									$template = "Citrix_Windows_81.xml"
								}
								elseif ($OSName -like '*Server 2008 R2*') {
									$template = "Citrix_Windows_Server_2008R2.xml"
								}
								elseif ($OSName -like '*Server 2012 R2*') {
									$template = "Citrix_Windows_Server_2012R2.xml"
								}
								elseif ($OSName -like '*Server 2016*') {
									$ReleaseID = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\" -Name ReleaseID).ReleaseId
									$template = "Citrix_Windows_Server_2016_$($ReleaseID).xml"
								}
								elseif ($OSName -like '*Server 2019*') {
									$ReleaseID = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\" -Name ReleaseID).ReleaseId
									$template = "Citrix_Windows_Server_2019_$($ReleaseID).xml"
								}
								else {
									Write-BISFLog -Msg "There is no appropriate Template for $AppName . No optimization by $AppName"
									break
								}
							}
							else {
								Write-BISFLog -Msg "Template Path for $AppName is configured by GPO: $LIC_BISF_CLI_CTXOE_TP"
								$templates = $LIC_BISF_CLI_CTXOE_TP
							}
							Write-BISFLog -Msg "Template for $AppName : $templates"

							#Groups
							if (($LIC_BISF_CLI_CTXOE_GROUPS -eq "") -or ($LIC_BISF_CLI_CTXOE_GROUPS -eq $null)) {
								Write-BISFLog -Msg "No groups for $AppName are configured by GPO. We will execute all available groups"
								$groups = ""
							}
							else {
								Write-BISFLog -Msg "Groups for $AppName configured by GPO: $LIC_BISF_CLI_CTXOE_GROUPS"
								$groups_reg = ($LIC_BISF_CLI_CTXOE_GROUPS).Split(',')
								$groups = $null
								foreach ($entry in $groups_reg) {
									$groups += """$entry"","
								}
								$groups = $groups.Substring(0, ($groups.Length - 1))
								$groups = " -Groups $groups "
							}

							#Mode
							if ($LIC_BISF_CLI_CTXOE_Analyze -ne "true") {
								$mode = "execute"
							}
							else {
								$mode = "analyze"
							}

							#Commandline
							ForEach ($template in $templates.split(","))   
							{
								IF (Test-Path "$CTXOTemplatePath\$template") {
									Write-BISFlog -Msg "Using Template $CTXOTemplatePath\$template" -ShowConsole -SubMsg -Color DarkCyan
									Write-BISFLog -Msg "Create temporary CMD-File ($tmpPS1) to run $AppName from them"
									$logfolder_bisf = (Get-Item -Path $logfile | Select-Object -ExpandProperty Directory).FullName
									$timestamp = Get-Date -Format yyyyMMdd-HHmmss
									$output_XML = "$logfolder_bisf\Prep_BIS_CTXOE_$($computer)_$timestamp.xml"
									"& ""$fileExists"" -Source ""$template""$groups-mode $mode -OutputXml ""$output_xml""" | Out-File $tmpPS1 -Encoding default
									$Global:LIC_BISF_3RD_OPT = $true # BIS-F own optimization will be disabled, if 3rd Party Optimization is true
									$ctxoe_proc = Start-Process -FilePath powershell.exe -ArgumentList "-file $tmpPS1" -WindowStyle Hidden -PassThru
									Show-BISFProgressBar -CheckProcessId $ctxoe_proc.Id -ActivityText "Running $AppName...please wait"
									Remove-Item $tmpPS1 -Force

									#CTXOE Logfile
									$scriptfolder = (Get-Item -Path $FileExists | Select-Object -ExpandProperty Directory).FullName
									$logfolder = "$scriptfolder\Logs"
									$logfile_path = Get-ChildItem -Path "$logfolder" -filter "Log_Debug_CTXOE.log" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {$_.FullName} | Select-Object -Last 1
									Write-BISFLog -Msg "Add $AppName logfile from $logfile_path to BIS-F logfile"
									Get-BISFLogContent -GetLogFile $logfile_path
								}
								ELSE {
									Write-BISFLog -Msg "ERROR: Citrix Optimizer Template $CTXOTemplatePath\$template NOT exists !!" -Type E -SubMsg
								}
							}
						}
						ELSE {
							Write-BISFLog -Msg "No optimization by $AppName"
						}
					}
				}
			}
		}
		ELSE {
			Write-BISFLog -Msg "Skip searching and running $AppName"
		}
	}

	#Citrix Applayering
	function Start-AppLayering {
		IF (!($CTXAppLayerName -eq "No-ELM")) {
			IF ($CTXAppLayeringSW) {
				$tmpLogFile = "C:\Windows\logs\BISFtmpProcessLog.log"
				Write-BISFLog -Msg "Prepare Citrix AppLayering" -ShowConsole -Color Cyan
				$txt = "Prepare AppLayering - List and remove unused network devices"
				Write-BISFLog -Msg "$txt" -ShowConsole -Color DarkCyan -SubMsg
				$ctxAppLay1 = Start-Process -FilePath "${env:ProgramFiles}\Unidesk\Uniservice\Uniservice.exe" -ArgumentList "-G" -NoNewWindow -RedirectStandardOutput "$tmpLogFile"
				Show-BISFProgressBar -CheckProcessId $ctxAppLay1.Id -ActivityText "$txt"
				Get-BISFLogContent -GetLogFile "$tmpLogFile"
				Remove-Item -Path "$tmpLogFile" -Force | Out-Null

				$txt = "Prepare AppLayering - Check System Layer integrity"
				Write-BISFLog -Msg "$txt" -ShowConsole -Color DarkCyan -SubMsg
				$ctxAppLay2 = Start-Process -FilePath "${env:ProgramFiles}\Unidesk\Uniservice\Uniservice.exe" -ArgumentList "-L" -NoNewWindow -RedirectStandardOutput "$tmpLogFile"
				Show-BISFProgressBar -CheckProcessId $ctxAppLay2.Id -ActivityText "$txt"
				Get-BISFLogContent -GetLogFile "$tmpLogFile"
				$ctxAppLay2log = Test-BISFLog -CheckLogFile "$tmpLogFile" -SearchString "allowed"
				Remove-Item -Path "$tmpLogFile" -Force | Out-Null
				IF ($ctxAppLay2log -eq $true) {
					Write-BISFLog -Msg "Layer finalize is allowed" -ShowConsole -Color DarkCyan -SubMsg
				}
				ELSE {
					Write-BISFLog -Msg "Layer finalize is NOT allowed, this issue is sending out from AppLayering and not BIS-F, please check the BIS-F log for further informations" -SubMsg -Type E
				}

			}
		}
		ELSE {
			Write-BISFLog -Msg "AppLayering is running $($CTXAppLayerName), UniService must not optimized" -ShowConsole -Color Cyan
		}
	}

	function Invoke-CDS {
		$servicename = "BrokerAgent"
		IF ($LIC_BISF_CLI_CDS -eq "1") {
			Write-BISFLog -Msg "The $servicename would configured through ADMX.. delay operation configured" -ShowConsole -Color Cyan
			Invoke-BISFService -ServiceName "$servicename" -StartType disabled -Action stop
		}
		ELSE {
			Write-BISFLog -Msg "The $servicename would not configured through ADMX.. normal operation state"
		}

	}



	####################################################################
}

Process {
	#### Main Program
	$returnXenAppPrep = XenAppPrep

	IF ($returnXenAppPrep -eq "true") {
		#XenApp Installation
		SetSTA
		RedirectLicFile
		CleanUpRadeCache
		CleanUpCTXPolCache
		CleanUpProfileManagement
		CleanUpEdgeSight

	}

	IF (($returnTestXDSoftware -eq "true") -or ($returnTestPVSSoftware -eq "true")) {
		#Citrix PVS or Citrix VDA installed
		Test-MSMQ
		Set-WEMAgent

		IF ($returnTestXDSoftware -eq "true") { # Citrix VDA only
			Invoke-CDS
		}

	}
	Start-AppLayering
	Start-CTXOE
}
End {
	Add-BISFFinishLine
}
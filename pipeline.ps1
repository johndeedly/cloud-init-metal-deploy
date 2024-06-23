#!/usr/bin/env pwsh
function Packer-BuildAppliance {
	param([Parameter()][string]$SearchFileName, [Parameter()][string]$Filter, [Parameter()][string]$ArgList)
	$runit = $false
	if ([System.String]::IsNullOrEmpty($SearchFileName)) {
		$runit = $true
	} else {
		$files = [System.IO.Directory]::GetFiles($PWD.ProviderPath + "/output", $SearchFileName, [System.IO.SearchOption]::AllDirectories)	
		if (-Not([System.String]::IsNullOrEmpty($Filter))) {
			$files = [Linq.Enumerable]::Where($files, [Func[string,bool]]{ param($x) $x -match $Filter })
		}
		$file = [Linq.Enumerable]::FirstOrDefault($files)
		Write-Host $file
		if ([System.String]::IsNullOrEmpty($file)) {
			$runit = $true
		}
	}
	if ($runit) {
		if ($IsWindows -or $env:OS) {
			$env:PKR_VAR_sound_driver = "dsound"
			$env:PKR_VAR_accel_graphics = "off"
			$process = Start-Process -PassThru -Wait -NoNewWindow -FilePath "packer.exe" -ArgumentList $ArgList
			return $process.ExitCode
		} else {
			$env:PKR_VAR_sound_driver = "pulse"
			$env:PKR_VAR_accel_graphics = "off"
			$process = Start-Process -PassThru -Wait -FilePath "packer" -ArgumentList $ArgList
			return $process.ExitCode
		}
	}
	return 0
}

New-Item -Path $PWD.ProviderPath -Name "output" -ItemType "directory" -Force | Out-Null
$env:PACKER_LOG=1
if ($IsWindows -or $env:OS -or $ForceVirtualbox) {
  # VBOX
  $env:PACKER_LOG_PATH="output/cloud.ready-packerlog.txt"
  if ((Packer-BuildAppliance -SearchFileName "*cloud.ready*.ova" -ArgList "build -force -on-error=ask -only=virtualbox-iso.default cloud.ready.pkr.hcl") -ne 0) {
  	break
  }
} else {
  # QEMU
  $env:PACKER_LOG_PATH="output/cloud.ready-packerlog.txt"
  if ((Packer-BuildAppliance -SearchFileName "*cloud.ready*.qcow2" -ArgList "build -force -on-error=ask -only=qemu.default cloud.ready.pkr.hcl") -ne 0) {
  	break
  }
}

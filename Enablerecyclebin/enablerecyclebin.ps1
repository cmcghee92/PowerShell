#enable Recycle Bin
Enable-ADOptionalFeature -Identity 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target 'Adatum.com' -Confirm:$false
@{
    SectionDefaults = @{
        "Pre-attack" = @{
            ValidationMode = "LiveReadOnly"
            Risk = "ExternalReadOnly"
            Notes = "Requires target tenant or internet-facing lookups."
        }
        "Access" = @{
            ValidationMode = "ManualLive"
            Risk = "SessionManagement"
            Notes = "Prompts for credentials and establishes live service sessions."
        }
        "Recon" = @{
            ValidationMode = "LiveReadOnly"
            Risk = "TenantReadOnly"
            Notes = "Requires active service sessions and tenant data."
        }
        "Account" = @{
            ValidationMode = "LiveMutating"
            Risk = "TenantWrite"
            Notes = "Creates, updates, or removes account state."
        }
        "Group" = @{
            ValidationMode = "LiveMutating"
            Risk = "TenantWrite"
            Notes = "Creates groups, changes membership, or assigns roles."
        }
        "Application" = @{
            ValidationMode = "LiveMutating"
            Risk = "TenantWrite"
            Notes = "Creates applications or rotates credentials."
        }
        "Entra" = @{
            ValidationMode = "LiveMutating"
            Risk = "TenantWrite"
            Notes = "Changes Entra tenant state or runs large exports."
        }
        "Exchange" = @{
            ValidationMode = "LiveMutating"
            Risk = "TenantWrite"
            Notes = "Changes mailbox, transport, or anti-phishing state."
        }
        "Teams" = @{
            ValidationMode = "LiveMutating"
            Risk = "TenantWrite"
            Notes = "Creates or invites live Teams objects."
        }
        "Sharepoint" = @{
            ValidationMode = "LiveMutating"
            Risk = "TenantWrite"
            Notes = "Changes SharePoint permissions or exports content."
        }
        "Compliance" = @{
            ValidationMode = "LiveMutating"
            Risk = "TenantWrite"
            Notes = "Creates, deletes, or exports compliance data."
        }
        "MAAD-AF" = @{
            ValidationMode = "ManualLocal"
            Risk = "LocalConfiguration"
            Notes = "Interactive local configuration changes should be reviewed manually."
        }
        "Exit" = @{
            ValidationMode = "ManualLocal"
            Risk = "LocalSession"
            Notes = "Interactive exit paths are not executed by the harness."
        }
    }
    DefaultHelper = @{
        ValidationMode = "Static"
        Risk = "Helper"
        Notes = "Validated for parse and load only unless a smoke test override exists."
    }
    FunctionOverrides = @{
        "InitializeMAADPowerShellLimits" = @{
            ValidationMode = "Smoke"
            SmokeTest = "InitializeMAADPowerShellLimits"
            Risk = "LocalSafe"
            Notes = "Raises session limits for large Entra and Graph modules."
        }
        "CreateLocalDir" = @{
            ValidationMode = "Smoke"
            SmokeTest = "CreateLocalDir"
            Risk = "LocalSafe"
            Notes = "Creates MAAD local files inside an isolated test workspace."
        }
        "CreateOutputsDir" = @{
            ValidationMode = "Smoke"
            SmokeTest = "CreateOutputsDir"
            Risk = "LocalSafe"
            Notes = "Creates the Outputs directory inside an isolated test workspace."
        }
        "GetMAADEntraScopes" = @{
            ValidationMode = "Smoke"
            SmokeTest = "GetMAADEntraScopes"
            Risk = "Helper"
            Notes = "Validates the centralized Entra delegated scope list."
        }
        "GetMAADCredentialSummaryValue" = @{
            ValidationMode = "Smoke"
            SmokeTest = "GetMAADCredentialSummaryValue"
            Risk = "Helper"
            Notes = "Validates credential summary rendering for UI tables."
        }
        "TestMAADGraphAudience" = @{
            ValidationMode = "Smoke"
            SmokeTest = "TestMAADGraphAudience"
            Risk = "Helper"
            Notes = "Validates Microsoft Graph audience detection."
        }
        "GetMAADTokenValidationMessage" = @{
            ValidationMode = "Smoke"
            SmokeTest = "GetMAADTokenValidationMessage"
            Risk = "Helper"
            Notes = "Validates token audience and legacy-token warnings."
        }
        "GetMAADValidGraphToken" = @{
            ValidationMode = "Smoke"
            SmokeTest = "GetMAADValidGraphToken"
            Risk = "Helper"
            Notes = "Validates runtime token acceptance logic."
        }
        "GetMAADExceptionMessage" = @{
            ValidationMode = "Smoke"
            SmokeTest = "GetMAADExceptionMessage"
            Risk = "Helper"
            Notes = "Normalizes nested Entra access exceptions."
        }
        "GetMAADReconErrorMessage" = @{
            ValidationMode = "Smoke"
            SmokeTest = "GetMAADReconErrorMessage"
            Risk = "Helper"
            Notes = "Normalizes recon exception messages."
        }
        "AddCredentials" = @{
            ValidationMode = "Smoke"
            SmokeTest = "AddCredentials"
            Risk = "LocalSafe"
            Notes = "Validates local credential store writes in the isolated workspace."
        }
        "Show-MAADOutput" = @{
            ValidationMode = "Smoke"
            SmokeTest = "ShowMAADOutput"
            Risk = "LocalSafe"
            Notes = "Validates output export without opening an interactive window."
        }
    }
}

package runtime

cliCommands: [
    "doctor",
    "compile-screen-doc",
    "validate",
    "generate",
    "generate-bundle",
    "preview-serve",
    "audit",
    "v2",
]

mcpTools: [
    "doctor",
    "compile_screen_doc",
    "validate_spec",
    "generate_screen",
    "generate_bundle",
    "preview_serve",
    "audit_project",
]

docSyncCommands: [
    "sync",
    "export-contracts",
    "export-fragments",
    "render",
    "verify",
]

evidenceKeys: [
    "swift_test",
    "cli_smoke",
    "mcp_smoke",
    "docsync_sync",
    "docsync_verify",
    "audit_json",
    "doctor_report",
    "integration_smoke",
    "acceptance_report",
    "reread_checklist",
]

doctorCapabilities: [
    "cli",
    "mcp",
    "ios_renderer",
    "android_renderer",
    "html_preview",
    "ios_host_smoke",
    "android_host_smoke",
]

doctorToolchains: [
    "swiftc",
    "python3",
    "java_runtime",
    "kotlin",
    "kotlinc",
    "gradle",
]

paths: {
    governanceFragmentSpec: "meta/views/governance.fragments.json",
    docSyncManifest: "meta/views/docsync.manifest.json",
    runtimeContractView: "meta/views/runtime.contracts.json",
    governanceContractView: "meta/views/governance.contracts.json",
}

exitCodes: {
    operational: 1,
    validationFailure: 2,
    bundleFailure: 4,
    auditFailure: 5,
}

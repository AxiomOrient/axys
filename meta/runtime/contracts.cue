package runtime

cliCommands: [
    "doctor",
    "validate-app",
    "validate-flow",
    "validate-screen",
    "render-html",
    "generate-native",
    "sync-penpot",
    "sync-pencil",
    "build-sample-apps",
    "preview-serve",
    "audit",
]

mcpTools: [
    "doctor",
    "validate_app",
    "validate_flow",
    "validate_screen",
    "render_html",
    "generate_native",
    "sync_penpot",
    "sync_pencil",
    "build_sample_apps",
    "preview_serve",
    "audit",
]

evidenceKeys: [
    "swift_test",
    "cli_smoke",
    "mcp_smoke",
    "audit_json",
    "doctor_report",
    "preview_smoke",
    "browser_evidence",
    "host_proof",
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

exitCodes: {
    operational: 1,
    validationFailure: 2,
    bundleFailure: 4,
    auditFailure: 5,
}

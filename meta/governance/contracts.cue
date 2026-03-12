package governance

generatedDocs: [
    "docs/11-execution-plan.md",
    "docs/12-task-matrix.md",
    "docs/20-traceability-matrix.md",
    "docs/23-authoritative-source-architecture.md",
    "docs/24-authoritative-source-execution-plan.md",
    "docs/25-authoritative-source-task-matrix.md",
]

authoritativeRoots: [
    "schemas",
    "examples",
    "docs/03-source-of-truth-and-contracts.md",
    "docs/06-data-models-and-schemas.md",
    "docs/08-generation-architecture.md",
    "docs/17-host-integration-guides.md",
    "docs/21-integrity-audit.md",
    "docs/22-validation-report.md",
    "meta/runtime/contracts.cue",
    "meta/governance/contracts.cue",
    "meta/views/governance.fragments.json",
]

evidenceRefs: [
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

runtimeArtifacts: [
    {
        id: "local_doctor"
        path: "audit/evidence/runtime/doctor.json"
        evidenceRef: "doctor_report"
    },
]

planningArtifacts: [
    {
        id: "authoritative_source_reread"
        path: "audit/evidence/planning/reread-checklist.json"
        evidenceRef: "reread_checklist"
    },
]

integrationArtifacts: [
    {
        id: "ios_host_smoke"
        path: "audit/evidence/integration/ios-host-smoke.json"
        evidenceRef: "integration_smoke"
    },
    {
        id: "android_host_smoke"
        path: "audit/evidence/integration/android-host-smoke.json"
        evidenceRef: "integration_smoke"
    },
]

acceptanceArtifacts: [
    {
        id: "login_acceptance"
        path: "audit/evidence/acceptance/login.json"
        evidenceRef: "acceptance_report"
    },
    {
        id: "product_detail_acceptance"
        path: "audit/evidence/acceptance/product-detail.json"
        evidenceRef: "acceptance_report"
    },
]

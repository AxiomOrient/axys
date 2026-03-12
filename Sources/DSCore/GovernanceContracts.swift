import Foundation

public struct GovernanceArtifact: Codable, Sendable, Equatable {
    public let id: String
    public let path: String
    public let evidenceRef: String

    public init(id: String, path: String, evidenceRef: String) {
        self.id = id
        self.path = path
        self.evidenceRef = evidenceRef
    }
}

public enum GovernanceEvidenceStatus: String, Codable, Sendable, Equatable {
    case pass
    case partial
    case blocked
}

public struct GovernanceVerificationEvidence: Codable, Sendable, Equatable {
    public let command: String
    public let testCase: String
    public let testSource: String

    public init(command: String, testCase: String, testSource: String) {
        self.command = command
        self.testCase = testCase
        self.testSource = testSource
    }
}

public struct DoctorEvidenceReport: Codable, Sendable, Equatable {
    public let artifactId: String
    public let artifactType: String
    public let verifiedOn: String
    public let verification: GovernanceVerificationEvidence
    public let report: DoctorReport

    public init(
        artifactId: String,
        artifactType: String,
        verifiedOn: String,
        verification: GovernanceVerificationEvidence,
        report: DoctorReport
    ) {
        self.artifactId = artifactId
        self.artifactType = artifactType
        self.verifiedOn = verifiedOn
        self.verification = verification
        self.report = report
    }
}

public struct PlanningRereadEvidenceReport: Codable, Sendable, Equatable {
    public let artifactId: String
    public let artifactType: String
    public let verifiedOn: String
    public let documents: [String]
    public let notes: [String]

    public init(
        artifactId: String,
        artifactType: String,
        verifiedOn: String,
        documents: [String],
        notes: [String]
    ) {
        self.artifactId = artifactId
        self.artifactType = artifactType
        self.verifiedOn = verifiedOn
        self.documents = documents.sorted()
        self.notes = notes
    }
}

public struct IntegrationSmokeEvidence: Codable, Sendable, Equatable {
    public let artifactId: String
    public let artifactType: String
    public let platform: String
    public let status: GovernanceEvidenceStatus
    public let verifiedOn: String
    public let requiredCapability: String
    public let doctorEvidence: String
    public let wrapperSources: [String]
    public let verification: GovernanceVerificationEvidence
    public let knownGap: String?
    public let notes: [String]

    public init(
        artifactId: String,
        artifactType: String,
        platform: String,
        status: GovernanceEvidenceStatus,
        verifiedOn: String,
        requiredCapability: String,
        doctorEvidence: String,
        wrapperSources: [String],
        verification: GovernanceVerificationEvidence,
        knownGap: String?,
        notes: [String]
    ) {
        self.artifactId = artifactId
        self.artifactType = artifactType
        self.platform = platform
        self.status = status
        self.verifiedOn = verifiedOn
        self.requiredCapability = requiredCapability
        self.doctorEvidence = doctorEvidence
        self.wrapperSources = wrapperSources.sorted()
        self.verification = verification
        self.knownGap = knownGap
        self.notes = notes
    }
}

public struct AcceptanceEvidenceInputs: Codable, Sendable, Equatable {
    public let screenDoc: String
    public let screenSpec: String

    public init(screenDoc: String, screenSpec: String) {
        self.screenDoc = screenDoc
        self.screenSpec = screenSpec
    }
}

public struct AcceptanceReviewCheck: Codable, Sendable, Equatable {
    public let id: String
    public let note: String

    public init(id: String, note: String) {
        self.id = id
        self.note = note
    }
}

public struct AcceptanceReviewEvidence: Codable, Sendable, Equatable {
    public let reviewedPreviewStates: [String]
    public let checklist: [AcceptanceReviewCheck]

    public init(reviewedPreviewStates: [String], checklist: [AcceptanceReviewCheck]) {
        self.reviewedPreviewStates = reviewedPreviewStates.sorted()
        self.checklist = checklist.sorted { ($0.id, $0.note) < ($1.id, $1.note) }
    }
}

public struct AcceptanceEvidenceReport: Codable, Sendable, Equatable {
    public let artifactId: String
    public let artifactType: String
    public let screenId: String
    public let status: GovernanceEvidenceStatus
    public let verifiedOn: String
    public let authoringInputs: AcceptanceEvidenceInputs
    public let verification: [String]
    public let review: AcceptanceReviewEvidence
    public let reviewSurface: String
    public let generatedManifest: String
    public let hostEvidence: [String]
    public let blockingHostEvidence: [String]
    public let residualGaps: [String]

    public init(
        artifactId: String,
        artifactType: String,
        screenId: String,
        status: GovernanceEvidenceStatus,
        verifiedOn: String,
        authoringInputs: AcceptanceEvidenceInputs,
        verification: [String],
        review: AcceptanceReviewEvidence,
        reviewSurface: String,
        generatedManifest: String,
        hostEvidence: [String],
        blockingHostEvidence: [String],
        residualGaps: [String]
    ) {
        self.artifactId = artifactId
        self.artifactType = artifactType
        self.screenId = screenId
        self.status = status
        self.verifiedOn = verifiedOn
        self.authoringInputs = authoringInputs
        self.verification = verification.sorted()
        self.review = review
        self.reviewSurface = reviewSurface
        self.generatedManifest = generatedManifest
        self.hostEvidence = hostEvidence.sorted()
        self.blockingHostEvidence = blockingHostEvidence.sorted()
        self.residualGaps = residualGaps
    }
}

public struct GovernanceContracts: Codable, Sendable, Equatable {
    public let generatedDocs: [String]
    public let authoritativeRoots: [String]
    public let evidenceRefs: [String]
    public let runtimeArtifacts: [GovernanceArtifact]
    public let planningArtifacts: [GovernanceArtifact]
    public let integrationArtifacts: [GovernanceArtifact]
    public let acceptanceArtifacts: [GovernanceArtifact]

    public init(
        generatedDocs: [String],
        authoritativeRoots: [String],
        evidenceRefs: [String],
        runtimeArtifacts: [GovernanceArtifact],
        planningArtifacts: [GovernanceArtifact],
        integrationArtifacts: [GovernanceArtifact],
        acceptanceArtifacts: [GovernanceArtifact]
    ) {
        self.generatedDocs = generatedDocs
        self.authoritativeRoots = authoritativeRoots
        self.evidenceRefs = evidenceRefs
        self.runtimeArtifacts = runtimeArtifacts.sorted { ($0.id, $0.path) < ($1.id, $1.path) }
        self.planningArtifacts = planningArtifacts.sorted { ($0.id, $0.path) < ($1.id, $1.path) }
        self.integrationArtifacts = integrationArtifacts.sorted { ($0.id, $0.path) < ($1.id, $1.path) }
        self.acceptanceArtifacts = acceptanceArtifacts.sorted { ($0.id, $0.path) < ($1.id, $1.path) }
    }
}

public enum GovernanceContractError: Error, LocalizedError {
    case missingField(String)
    case invalidFormat(String)

    public var errorDescription: String? {
        switch self {
        case .missingField(let field):
            return "Missing governance contract field: \(field)"
        case .invalidFormat(let message):
            return message
        }
    }
}

public struct GovernanceContractLoader: Sendable {
    public init() {}

    public func load(from url: URL) throws -> GovernanceContracts {
        let text = try String(contentsOf: url)
        return GovernanceContracts(
            generatedDocs: try stringArray(named: "generatedDocs", in: text),
            authoritativeRoots: try stringArray(named: "authoritativeRoots", in: text),
            evidenceRefs: try stringArray(named: "evidenceRefs", in: text),
            runtimeArtifacts: try artifactArray(named: "runtimeArtifacts", in: text),
            planningArtifacts: try artifactArray(named: "planningArtifacts", in: text),
            integrationArtifacts: try artifactArray(named: "integrationArtifacts", in: text),
            acceptanceArtifacts: try artifactArray(named: "acceptanceArtifacts", in: text)
        )
    }

    private func stringArray(named field: String, in text: String) throws -> [String] {
        let block = try block(named: field, open: "[", close: "]", in: text)
        let matches = block.matches(of: /"([^"]+)"/)
        let values = matches.map { String($0.1) }
        guard !values.isEmpty else {
            throw GovernanceContractError.invalidFormat("Governance contract array '\(field)' is empty or malformed")
        }
        return values
    }

    private func artifactArray(named field: String, in text: String) throws -> [GovernanceArtifact] {
        let arrayBlock = try block(named: field, open: "[", close: "]", in: text)
        var artifacts: [GovernanceArtifact] = []
        var cursor = arrayBlock.startIndex

        while cursor < arrayBlock.endIndex {
            guard let openBrace = arrayBlock[cursor...].firstIndex(of: "{") else {
                break
            }

            var index = openBrace
            var depth = 0
            while index < arrayBlock.endIndex {
                let character = arrayBlock[index]
                if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        let object = String(arrayBlock[openBrace...index])
                        artifacts.append(
                            GovernanceArtifact(
                                id: try stringValue(named: "id", inObject: object, field: field),
                                path: try stringValue(named: "path", inObject: object, field: field),
                                evidenceRef: try stringValue(named: "evidenceRef", inObject: object, field: field)
                            )
                        )
                        cursor = arrayBlock.index(after: index)
                        break
                    }
                }
                index = arrayBlock.index(after: index)
            }

            if depth != 0 {
                throw GovernanceContractError.invalidFormat("Governance contract field '\(field)' has an unterminated object")
            }
        }

        return artifacts
    }

    private func stringValue(named name: String, inObject object: String, field: String) throws -> String {
        let pattern = "\(NSRegularExpression.escapedPattern(for: name)):\\s*\"([^\"]+)\""
        guard let value = firstCapture(in: object, pattern: pattern) else {
            throw GovernanceContractError.invalidFormat("Governance contract artifact in '\(field)' is missing '\(name)'")
        }
        return value
    }

    private func block(named field: String, open: Character, close: Character, in text: String) throws -> String {
        guard let fieldRange = text.range(of: "\(field):") else {
            throw GovernanceContractError.missingField(field)
        }

        var cursor = fieldRange.upperBound
        while cursor < text.endIndex, text[cursor].isWhitespace {
            cursor = text.index(after: cursor)
        }

        guard cursor < text.endIndex, text[cursor] == open else {
            throw GovernanceContractError.invalidFormat("Governance contract field '\(field)' is not a \(open)...\(close) block")
        }

        let start = cursor
        var depth = 0
        while cursor < text.endIndex {
            let character = text[cursor]
            if character == open {
                depth += 1
            } else if character == close {
                depth -= 1
                if depth == 0 {
                    return String(text[start...cursor])
                }
            }
            cursor = text.index(after: cursor)
        }

        throw GovernanceContractError.invalidFormat("Governance contract field '\(field)' is missing closing \(close)")
    }

    private func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 else {
            return nil
        }
        guard let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }
}

import DSMCPKit
import Foundation
import MCP

@main
struct DSMCP {
    static func main() async throws {
        let server = await DSMCPServerFactory.makeServer()
        let transport = StdioTransport()
        try await server.start(transport: transport)

        while !Task.isCancelled {
            try await Task.sleep(for: .seconds(3600))
        }
    }
}

import Foundation

package func resolvedPreviewStatesForRendering(_ screen: ScreenSpec) -> [PreviewState] {
    if screen.previewStates.isEmpty {
        return [PreviewState(id: "default")]
    }
    return screen.previewStates
}

package func resolvedPreviewStateIDsForRendering(_ screen: ScreenSpec) -> [String] {
    resolvedPreviewStatesForRendering(screen).map(\.id)
}

import DSCore

func makeScreenWithEmptyPreviewStates(targets: [Platform]) -> ScreenSpec {
    ScreenSpec(
        schemaVersion: "1.0.0",
        appId: "checkout",
        flowId: "checkout-flow",
        screenId: "payment",
        title: "Payment",
        route: "/checkout/payment",
        targets: targets,
        surface: ScreenSurface(
            backgroundColor: "{color.surface.primary}",
            padding: "{space.400}"
        ),
        states: [],
        previewStates: [],
        layout: LayoutNode(kind: "stack")
    )
}

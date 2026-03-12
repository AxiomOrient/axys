import SwiftUI

final class ProductDetailHostStore {
    func addToCart() {}
    func showShippingDetails() {}
}

struct ProductDetailHostScreen: View {
    @State private var screenState = ProductDetailScreenState()
    private let store = ProductDetailHostStore()

    var body: some View {
        ProductDetailScreen(
            state: $screenState,
            actions: ProductDetailScreenActions(
                addToCart: { store.addToCart() }
            ),
            navigation: ProductDetailScreenNavigation(
                shippingDetails: { store.showShippingDetails() }
            )
        )
    }
}

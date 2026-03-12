import androidx.compose.runtime.Composable

class ProductDetailHostStore {
    val screenState = ProductDetailScreenState()

    fun addToCart() {}

    fun showShippingDetails() {}
}

@Composable
fun ProductDetailHostScreen(store: ProductDetailHostStore = ProductDetailHostStore()) {
    ProductDetailScreen(
        state = store.screenState,
        actions = ProductDetailScreenActions(
            onAddToCart = { store.addToCart() }
        ),
        navigation = ProductDetailScreenNavigation(
            onShippingDetails = { store.showShippingDetails() }
        )
    )
}
